#!/bin/bash

#===============================================================================
# SCRIPT DE PRUEBAS PARA SISTEMA DE RESPALDO AUTOMÁTICO
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

error_message() {
    echo -e "${RED}✗ $1${NC}"
}

warning_message() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Función para ejecutar pruebas
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Probando $test_name... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# Pruebas del sistema
test_dependencies() {
    info_message "Verificando dependencias..."
    
    local deps=("openssl" "tar" "gzip" "curl" "udevadm" "mount" "umount" "systemctl")
    local failed=0
    
    for dep in "${deps[@]}"; do
        if run_test "$dep" "command -v $dep"; then
            continue
        else
            ((failed++))
        fi
    done
    
    if [ $failed -eq 0 ]; then
        success_message "Todas las dependencias están disponibles"
    else
        error_message "$failed dependencias faltantes"
    fi
}

test_file_permissions() {
    info_message "Verificando permisos de archivos..."
    
    local files=(
        "$SCRIPT_DIR/principal.sh"
        "$SCRIPT_DIR/generar_llaves.sh"
        "$SCRIPT_DIR/setup_telegram.sh"
        "$SCRIPT_DIR/backup-usb-handler.sh"
        "$SCRIPT_DIR/backup-usb-cleanup.sh"
    )
    
    local failed=0
    
    for file in "${files[@]}"; do
        if [ -x "$file" ]; then
            run_test "$(basename "$file")" "true"
        else
            run_test "$(basename "$file")" "false"
            ((failed++))
        fi
    done
    
    if [ $failed -eq 0 ]; then
        success_message "Todos los archivos tienen permisos correctos"
    else
        error_message "$failed archivos sin permisos de ejecución"
    fi
}

test_configuration_syntax() {
    info_message "Verificando sintaxis de scripts..."
    
    local scripts=(
        "$SCRIPT_DIR/principal.sh"
        "$SCRIPT_DIR/generar_llaves.sh"
        "$SCRIPT_DIR/setup_telegram.sh"
        "$SCRIPT_DIR/backup-usb-handler.sh"
        "$SCRIPT_DIR/backup-usb-cleanup.sh"
        "$SCRIPT_DIR/install.sh"
    )
    
    local failed=0
    
    for script in "${scripts[@]}"; do
        if bash -n "$script" 2>/dev/null; then
            run_test "sintaxis $(basename "$script")" "true"
        else
            run_test "sintaxis $(basename "$script")" "false"
            ((failed++))
        fi
    done
    
    if [ $failed -eq 0 ]; then
        success_message "Sintaxis correcta en todos los scripts"
    else
        error_message "$failed scripts con errores de sintaxis"
    fi
}

test_openssl_functionality() {
    info_message "Verificando funcionalidad de OpenSSL..."
    
    local temp_dir=$(mktemp -d)
    local private_key="$temp_dir/test_private.pem"
    local public_key="$temp_dir/test_public.pem"
    local test_file="$temp_dir/test.txt"
    local signature="$temp_dir/test.sig"
    
    echo "Test message" > "$test_file"
    
    # Generar par de llaves
    if openssl genrsa -out "$private_key" 2048 >/dev/null 2>&1; then
        run_test "generación de llave privada" "true"
    else
        run_test "generación de llave privada" "false"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Extraer llave pública
    if openssl rsa -in "$private_key" -pubout -out "$public_key" >/dev/null 2>&1; then
        run_test "extracción de llave pública" "true"
    else
        run_test "extracción de llave pública" "false"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Firmar archivo
    if openssl dgst -sha256 -sign "$private_key" -out "$signature" "$test_file" >/dev/null 2>&1; then
        run_test "firma digital" "true"
    else
        run_test "firma digital" "false"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Verificar firma
    if openssl dgst -sha256 -verify "$public_key" -signature "$signature" "$test_file" >/dev/null 2>&1; then
        run_test "verificación de firma" "true"
    else
        run_test "verificación de firma" "false"
        rm -rf "$temp_dir"
        return 1
    fi
    
    rm -rf "$temp_dir"
    success_message "Funcionalidad de OpenSSL verificada"
}

create_test_usb_structure() {
    info_message "Creando estructura de prueba para USB..."
    
    local test_usb_dir="$SCRIPT_DIR/test_usb"
    
    mkdir -p "$test_usb_dir"
    
    # Crear archivo de configuración de prueba
    cat > "$test_usb_dir/backup_config.conf" << EOF
# Configuración de respaldo para pruebas
BACKUP_DIRS="/etc/hostname /etc/hosts"
BACKUP_NAME="servidor_prueba"
EXCLUDE_PATTERNS="*.tmp"
SYSADMIN_NAME="Admin Prueba"
BACKUP_DESCRIPTION="Respaldo de prueba"
EOF

    # Generar llave de prueba
    if command -v openssl >/dev/null 2>&1; then
        openssl genrsa -out "$test_usb_dir/sysadmin_key.pem" 2048 >/dev/null 2>&1
        echo "test_admin" > "$test_usb_dir/sysadmin_id.txt"
        success_message "Estructura de USB de prueba creada en: $test_usb_dir"
    else
        error_message "OpenSSL no disponible para crear estructura de prueba"
    fi
}

show_test_summary() {
    echo
    info_message "=== RESUMEN DE PRUEBAS ==="
    echo
    echo "Para probar el sistema manualmente:"
    echo "1. Instalar: sudo ./install.sh --install"
    echo "2. Configurar Telegram: sudo backup-telegram --setup"
    echo "3. Generar llaves: sudo backup-genkeys test_admin"
    echo "4. Establecer contraseña: sudo backup-system --set-password 'test123'"
    echo "5. Verificar estado: sudo backup-system --status"
    echo
    echo "Estructura de prueba USB creada en: $SCRIPT_DIR/test_usb"
    echo
}

# Ejecutar todas las pruebas
main() {
    echo -e "${BLUE}=== PRUEBAS DEL SISTEMA DE RESPALDO AUTOMÁTICO ===${NC}\n"
    
    test_dependencies
    echo
    test_file_permissions
    echo
    test_configuration_syntax
    echo
    test_openssl_functionality
    echo
    create_test_usb_structure
    
    show_test_summary
}

main "$@"
