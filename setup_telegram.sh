#!/bin/bash

#===============================================================================
# CONFIGURADOR DE TELEGRAM PARA SISTEMA DE RESPALDO
#===============================================================================

CONFIG_DIR="/etc/backup-system"
TELEGRAM_CONFIG="$CONFIG_DIR/telegram.conf"

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

setup_telegram_bot() {
    echo -e "${BLUE}=== Configuración del Bot de Telegram ===${NC}\n"
    
    echo "Para configurar las notificaciones de Telegram necesitas:"
    echo "1. Crear un bot en Telegram con @BotFather"
    echo "2. Obtener el token del bot"
    echo "3. Obtener el chat_id de cada sysadmin"
    echo
    
    read -p "¿Token del bot de Telegram? " bot_token
    
    if [ -z "$bot_token" ]; then
        error_exit "Token del bot es requerido"
    fi
    
    # Crear directorio si no existe
    mkdir -p "$CONFIG_DIR"
    
    # Crear archivo de configuración
    cat > "$TELEGRAM_CONFIG" << EOF
# Configuración de Telegram Bot
BOT_TOKEN="$bot_token"

# Mapeo de sysadmin_id a chat_id
# Formato: sysadmin_id:chat_id
EOF

    chmod 600 "$TELEGRAM_CONFIG"
    
    success_message "Configuración base de Telegram creada"
    
    # Agregar sysadmins
    while true; do
        echo
        read -p "¿ID del sysadmin (o 'fin' para terminar)? " sysadmin_id
        
        if [ "$sysadmin_id" = "fin" ]; then
            break
        fi
        
        if [ -z "$sysadmin_id" ]; then
            continue
        fi
        
        read -p "¿Chat ID de Telegram para $sysadmin_id? " chat_id
        
        if [ -z "$chat_id" ]; then
            continue
        fi
        
        echo "$sysadmin_id:$chat_id" >> "$TELEGRAM_CONFIG"
        success_message "Sysadmin $sysadmin_id agregado"
    done
    
    echo
    success_message "Configuración de Telegram completada"
    info_message "Archivo de configuración: $TELEGRAM_CONFIG"
}

test_telegram_notification() {
    if [ ! -f "$TELEGRAM_CONFIG" ]; then
        error_exit "Configuración de Telegram no encontrada. Ejecute primero la configuración."
    fi
    
    source "$TELEGRAM_CONFIG"
    
    if [ -z "$BOT_TOKEN" ]; then
        error_exit "Token del bot no configurado"
    fi
    
    echo -e "${BLUE}=== Prueba de Notificaciones ===${NC}\n"
    
    read -p "¿ID del sysadmin a probar? " sysadmin_id
    
    local chat_id=$(grep "^$sysadmin_id:" "$TELEGRAM_CONFIG" | cut -d':' -f2)
    
    if [ -z "$chat_id" ]; then
        error_exit "Chat ID no encontrado para sysadmin: $sysadmin_id"
    fi
    
    local url="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"
    local message="🔧 Prueba del sistema de respaldo automático desde servidor $(hostname)"
    local payload="{\"chat_id\": \"$chat_id\", \"text\": \"$message\"}"
    
    info_message "Enviando mensaje de prueba..."
    
    local response=$(curl -s -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    if echo "$response" | grep -q '"ok":true'; then
        success_message "Notificación de prueba enviada exitosamente"
    else
        error_exit "Error al enviar notificación: $response"
    fi
}

show_help() {
    cat << EOF
Configurador de Telegram para Sistema de Respaldo

Uso: $0 [OPCIÓN]

OPCIONES:
    --setup    Configurar bot y sysadmins
    --test     Probar notificaciones
    --help     Mostrar esta ayuda

Pasos para obtener chat_id:
1. Inicie una conversación con su bot
2. Envíe cualquier mensaje al bot
3. Visite: https://api.telegram.org/bot<TOKEN>/getUpdates
4. Busque el "chat":{"id":XXXXXXXXX} en la respuesta

EOF
}

case "${1:-}" in
    --setup)
        setup_telegram_bot
        ;;
    --test)
        test_telegram_notification
        ;;
    --help|"")
        show_help
        ;;
    *)
        error_exit "Opción no válida: $1"
        ;;
esac