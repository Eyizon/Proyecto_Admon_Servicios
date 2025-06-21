#!/bin/bash

#===============================================================================
# MANEJADOR DE EVENTOS USB PARA SISTEMA DE RESPALDO
#===============================================================================

DEVICE="$1"
LOG_FILE="/var/log/backup-system/usb-events.log"
LOCK_FILE="/tmp/backup-system/usb-processing.lock"

# Función de logging
log_event() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] USB Handler: $1" >> "$LOG_FILE"
}

# Verificar que se proporcione un dispositivo
if [ -z "$DEVICE" ]; then
    log_event "ERROR: No se especificó dispositivo"
    exit 1
fi

log_event "Dispositivo USB detectado: $DEVICE"

# Verificar si ya hay un proceso de respaldo en curso
if [ -f "$LOCK_FILE" ]; then
    log_event "WARNING: Proceso de respaldo ya en curso, ignorando $DEVICE"
    exit 0
fi

# Crear lock file
touch "$LOCK_FILE"

# Esperar un momento para que el dispositivo se monte completamente
sleep 5

# Buscar punto de montaje del dispositivo
MOUNT_POINT=""
for i in {1..10}; do
    MOUNT_POINT=$(mount | grep "/dev/$DEVICE" | awk '{print $3}' | head -1)
    if [ ! -z "$MOUNT_POINT" ]; then
        break
    fi
    sleep 1
done

if [ -z "$MOUNT_POINT" ]; then
    log_event "ERROR: No se pudo encontrar punto de montaje para $DEVICE"
    rm -f "$LOCK_FILE"
    exit 1
fi

log_event "Dispositivo montado en: $MOUNT_POINT"

# Verificar si es una unidad de respaldo válida
if [ ! -f "$MOUNT_POINT/backup_config.conf" ]; then
    log_event "INFO: No es una unidad de respaldo válida (falta backup_config.conf)"
    rm -f "$LOCK_FILE"
    exit 0
fi

if [ ! -f "$MOUNT_POINT/sysadmin_key.pem" ]; then
    log_event "INFO: No es una unidad de respaldo válida (falta sysadmin_key.pem)"
    rm -f "$LOCK_FILE"
    exit 0
fi

log_event "Unidad de respaldo válida detectada, iniciando proceso..."

# Ejecutar el sistema de respaldo en segundo plano
nohup /usr/local/bin/backup-system --process-usb "$DEVICE" >> "$LOG_FILE" 2>&1 &

# El lock file será eliminado por el proceso principal
exit 0
