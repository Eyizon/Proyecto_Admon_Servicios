#!/bin/bash

#===============================================================================
# GENERADOR DE LLAVES PARA SISTEMA DE RESPALDO
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

generate_sysadmin_keys() {
    local sysadmin_id="$1"
    local output_dir="${2:-./keys}"
    
    if [ -z "$sysadmin_id" ]; then
        error_exit "Debe especificar el ID del sysadmin"
    fi
    
    mkdir -p "$output_dir"
    
    local private_key="$output_dir/${sysadmin_id}_private.pem"
    local public_key="$output_dir/${sysadmin_id}_public.pem"
    
    info_message "Generando par de llaves para sysadmin: $sysadmin_id"
    
    # Generar llave privada
    openssl genrsa -out "$private_key" 2048 || error_exit "Error al generar llave privada"
    chmod 600 "$private_key"
    
    # Extraer llave pública
    openssl rsa -in "$private_key" -pubout -out "$public_key" || error_exit "Error al extraer llave pública"
    
    # Crear archivo de ID del sysadmin
    echo "$sysadmin_id" > "$output_dir/sysadmin_id.txt"
    
    success_message "Llaves generadas exitosamente:"
    echo "  - Llave privada: $private_key"
    echo "  - Llave pública: $public_key"
    echo "  - ID del sysadmin: $output_dir/sysadmin_id.txt"
    
    info_message "Copie $private_key y sysadmin_id.txt a la unidad USB"
    info_message "Autorice $public_key en el servidor con: ./principal.sh --add-key $public_key"
}

show_help() {
    cat << EOF
Generador de Llaves para Sistema de Respaldo

Uso: $0 <sysadmin_id> [directorio_salida]

Parámetros:
    sysadmin_id       ID único del administrador de sistemas
    directorio_salida Directorio donde guardar las llaves (por defecto: ./keys)

Ejemplo:
    $0 admin1 /home/admin1/keys

EOF
}

if [ $# -lt 1 ]; then
    show_help
    exit 1
fi

generate_sysadmin_keys "$1" "$2"