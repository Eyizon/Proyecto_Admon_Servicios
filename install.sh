#!/bin/bash

#===============================================================================
# INSTALADOR DEL SISTEMA DE RESPALDO AUTOMÁTICO
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

success_message() {
    echo -e "${GREEN}✓ $1${NC}"
}

info_message() {
    echo -e "${BLUE}ℹ $1${NC}"
}

error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

warning_message() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error_exit "Este script debe ejecutarse como root"
    fi
}

install_dependencies() {
    info_message "Instalando dependencias..."
    
    apt-get update || error_exit "Error al actualizar repositorios"
    
    local packages=("openssl" "curl" "udev" "systemd")
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            info_message "Instalando $package..."
            apt-get install -y "$package" || error_exit "Error al instalar $package"
        else
            success_message "$package ya está instalado"
        fi
    done
}

setup_permissions() {
    info_message "Configurando permisos..."
    
    chmod +x "$SCRIPT_DIR/principal.sh"
    chmod +x "$SCRIPT_DIR/generar_llaves.sh"
    chmod +x "$SCRIPT_DIR/setup_telegram.sh"
    chmod +x "$SCRIPT_DIR/backup-usb-handler.sh"
    chmod +x "$SCRIPT_DIR/backup-usb-cleanup.sh"
    
    success_message "Permisos configurados"
}

create_symlinks() {
    info_message "Creando enlaces simbólicos..."
    
    ln -sf "$SCRIPT_DIR/principal.sh" /usr/local/bin/backup-system
    ln -sf "$SCRIPT_DIR/generar_llaves.sh" /usr/local/bin/backup-genkeys
    ln -sf "$SCRIPT_DIR/setup_telegram.sh" /usr/local/bin/backup-telegram
    ln -sf "$SCRIPT_DIR/backup-usb-handler.sh" /usr/local/bin/backup-usb-handler
    ln -sf "$SCRIPT_DIR/backup-usb-cleanup.sh" /usr/local/bin/backup-usb-cleanup
    
    success_message "Enlaces simbólicos creados en /usr/local/bin/"
}

install_udev_rules() {
    info_message "Instalando reglas udev..."
    
    if [ -f "$SCRIPT_DIR/99-backup-usb.rules" ]; then
        cp "$SCRIPT_DIR/99-backup-usb.rules" /etc/udev/rules.d/
        chmod 644 /etc/udev/rules.d/99-backup-usb.rules
        udevadm control --reload-rules
        success_message "Reglas udev instaladas"
    else
        warning_message "Archivo de reglas udev no encontrado"
    fi
}

install_systemd_service() {
    info_message "Instalando servicio systemd..."
    
    if [ -f "$SCRIPT_DIR/backup-system.service" ]; then
        cp "$SCRIPT_DIR/backup-system.service" /etc/systemd/system/
        chmod 644 /etc/systemd/system/backup-system.service
        systemctl daemon-reload
        success_message "Servicio systemd instalado"
    else
        warning_message "Archivo de servicio no encontrado"
    fi
}

install_system() {
    echo -e "${BLUE}=== Instalador del Sistema de Respaldo Automático ===${NC}\n"
    
    check_root
    install_dependencies
    setup_permissions
    create_symlinks
    install_udev_rules
    install_systemd_service
    
    # Ejecutar configuración inicial
    "$SCRIPT_DIR/principal.sh" --setup
    
    echo
    success_message "Instalación completada"
    
    echo -e "\n${YELLOW}Próximos pasos:${NC}"
    echo "1. Configurar Telegram: backup-telegram --setup"
    echo "2. Generar llaves para sysadmins: backup-genkeys <sysadmin_id>"
    echo "3. Establecer contraseña del servidor: backup-system --set-password <password>"
    echo "4. Habilitar servicio: systemctl enable backup-system.service"
    echo "5. Iniciar servicio: systemctl start backup-system.service"
    echo "6. Verificar estado: backup-system --status"
    echo
}

uninstall_system() {
    echo -e "${YELLOW}¿Está seguro de desinstalar el sistema? (y/N)${NC}"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        info_message "Desinstalando sistema..."
        
        # Detener y deshabilitar servicio
        systemctl stop backup-system.service 2>/dev/null
        systemctl disable backup-system.service 2>/dev/null
        rm -f /etc/systemd/system/backup-system.service
        systemctl daemon-reload
        
        # Eliminar enlaces simbólicos
        rm -f /usr/local/bin/backup-system
        rm -f /usr/local/bin/backup-genkeys
        rm -f /usr/local/bin/backup-telegram
        
        # Preguntar si eliminar configuración
        echo -e "${YELLOW}¿Eliminar archivos de configuración? (y/N)${NC}"
        read -r response2
        
        if [[ "$response2" =~ ^[Yy]$ ]]; then
            rm -rf /etc/backup-system
            rm -rf /var/log/backup-system
            success_message "Configuración eliminada"
        fi
        
        success_message "Sistema desinstalado"
    else
        info_message "Desinstalación cancelada"
    fi
}

show_help() {
    cat << EOF
Instalador del Sistema de Respaldo Automático

Uso: $0 [OPCIÓN]

OPCIONES:
    --install      Instalar el sistema
    --uninstall    Desinstalar el sistema
    --help         Mostrar esta ayuda

EOF
}

case "${1:-}" in
    --install|"")
        install_system
        ;;
    --uninstall)
        uninstall_system
        ;;
    --help)
        show_help
        ;;
    *)
        error_exit "Opción no válida: $1"
        ;;
esac