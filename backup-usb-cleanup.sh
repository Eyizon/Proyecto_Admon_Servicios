#!/bin/bash

#===============================================================================
# SCRIPT DE LIMPIEZA PARA DISPOSITIVOS USB DESCONECTADOS
#===============================================================================

DEVICE="$1"
LOG_FILE="/var/log/backup-system/usb-events.log"

# Función de logging
log_event() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] USB Cleanup: $1" >> "$LOG_FILE"
}

if [ -z "$DEVICE" ]; then
    log_event "ERROR: No se especificó dispositivo para limpieza"
    exit 1
fi

log_event "Dispositivo USB desconectado: $DEVICE"

# Limpiar archivos temporales específicos del dispositivo
rm -f "/tmp/backup-system/challenge_${DEVICE}.txt"
rm -f "/tmp/backup-system/signature_${DEVICE}.sig"
rm -f "/tmp/backup-system/temp_public_${DEVICE}.pem"

log_event "Limpieza completada para dispositivo: $DEVICE"
