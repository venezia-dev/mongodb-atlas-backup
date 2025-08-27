#!/usr/bin/env bash
set -euo pipefail

: "${OUTPUT_DIR:=/backups}"
: "${RETENTION_DAYS:=0}"
NOW="$(date +'%Y%m%d_%H%M%S')"

# Variables para tracking de errores
FAILED_DBS=()
SUCCESS_COUNT=0
TOTAL_COUNT=0

notify_error() {
  local db_name="$1"
  local error_msg="$2"
  if [[ "${NOTIFY_ON:-fail}" =~ ^(fail|both)$ ]]; then
    /app/notify.sh error "❌ Backup FAILED $(date -Is)
DB: ${db_name}
Error: ${error_msg}" || true
  fi
}

notify_summary() {
  if [ ${#FAILED_DBS[@]} -gt 0 ]; then
    local failed_list=$(IFS=', '; echo "${FAILED_DBS[*]}")
    /app/notify.sh error "📊 Backup Summary $(date -Is)
✅ Exitosos: ${SUCCESS_COUNT}/${TOTAL_COUNT}
❌ Fallidos: ${failed_list}" || true
  elif [[ "${NOTIFY_ON:-fail}" =~ ^(both|success)$ ]]; then
    /app/notify.sh info "✅ Backup Completo $(date -Is)
Todas las ${SUCCESS_COUNT} bases de datos respaldadas correctamente" || true
  fi
}

backup_single_db() {
  local db_name="$1"
  local archive_name="${BACKUP_PREFIX:-backup}_${db_name}_${NOW}.gz"
  local archive_path="${OUTPUT_DIR}/${archive_name}"
  
  echo "Iniciando backup de: ${db_name}"
  
  if mongodump --uri="$MONGO_URI" --db="$db_name" --archive="$archive_path" --gzip; then
    echo "✅ Backup exitoso: ${archive_path}"
    
    # Upload to S3 if configured
    if [[ "${S3_UPLOAD:-false}" == "true" ]]; then
      echo "Subiendo ${db_name} a S3..."
      if python3 /app/s3_upload.py "$archive_path"; then
        echo "✅ Upload S3 exitoso para: ${db_name}"
        # Remove local file if configured
        if [[ "${KEEP_LOCAL_BACKUP:-true}" == "false" ]]; then
          rm -f "$archive_path"
          echo "🗑️  Archivo local eliminado: ${archive_name}"
        fi
      else
        echo "❌ Error en upload S3 de: ${db_name}"
        notify_error "$db_name" "Upload a S3 falló"
        FAILED_DBS+=("${db_name}_S3")
        return 1
      fi
    fi
    
    ((SUCCESS_COUNT++))
    return 0
  else
    echo "❌ Error en backup de: ${db_name}"
    FAILED_DBS+=("$db_name")
    notify_error "$db_name" "mongodump falló"
    return 1
  fi
}

if [ -z "${MONGO_URI:-}" ]; then
  echo "ERROR: MONGO_URI no está configurado."
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Determinar qué bases de datos respaldar
if [ -n "${MONGO_DBS:-}" ]; then
  # Múltiples bases de datos separadas por comas
  echo "Modo múltiples BD: ${MONGO_DBS}"
  IFS=',' read -ra DBS_ARRAY <<< "${MONGO_DBS}"
  TOTAL_COUNT=${#DBS_ARRAY[@]}
  
  for db in "${DBS_ARRAY[@]}"; do
    # Limpiar espacios en blanco
    db=$(echo "$db" | xargs)
    if [ -n "$db" ]; then
      backup_single_db "$db" || true  # Continuar aunque falle una BD
    fi
  done
  
elif [ -n "${MONGO_DB:-}" ]; then
  # Una sola base de datos (compatibilidad hacia atrás)
  echo "Modo BD única: ${MONGO_DB}"
  TOTAL_COUNT=1
  backup_single_db "$MONGO_DB"
  
else
  # Todas las bases de datos del cluster
  echo "Modo todas las BD del cluster"
  ARCHIVE_NAME="${BACKUP_PREFIX:-backup}_all_${NOW}.gz"
  ARCHIVE_PATH="${OUTPUT_DIR}/${ARCHIVE_NAME}"
  TOTAL_COUNT=1
  
  echo "Iniciando mongodump completo..."
  if mongodump --uri="$MONGO_URI" --archive="$ARCHIVE_PATH" --gzip; then
    echo "✅ Backup completo exitoso: ${ARCHIVE_PATH}"
    
    # Upload to S3 if configured
    if [[ "${S3_UPLOAD:-false}" == "true" ]]; then
      echo "Subiendo backup completo a S3..."
      if python3 /app/s3_upload.py "$ARCHIVE_PATH"; then
        echo "✅ Upload S3 exitoso para backup completo"
        # Remove local file if configured
        if [[ "${KEEP_LOCAL_BACKUP:-true}" == "false" ]]; then
          rm -f "$ARCHIVE_PATH"
          echo "🗑️  Archivo local eliminado: ${ARCHIVE_NAME}"
        fi
      else
        echo "❌ Error en upload S3 del backup completo"
        notify_error "ALL" "Upload a S3 falló"
        FAILED_DBS+=("ALL_S3")
      fi
    fi
    
    SUCCESS_COUNT=1
  else
    echo "❌ Error en backup completo"
    FAILED_DBS+=("ALL")
    notify_error "ALL" "mongodump completo falló"
  fi
fi

# Retención
if [ "${RETENTION_DAYS}" -gt 0 ]; then
  echo "Aplicando retención: ${RETENTION_DAYS} días"
  find "$OUTPUT_DIR" -type f -name "${BACKUP_PREFIX:-backup}_*.gz" -mtime +${RETENTION_DAYS} -print -delete || true
fi

# Notificar resumen
notify_summary

# Marca último OK (para healthcheck) solo si al menos una BD fue exitosa
if [ $SUCCESS_COUNT -gt 0 ]; then
  date -Is > /app/last_success.txt
  echo "OK: backup finalizado. Exitosos: ${SUCCESS_COUNT}/${TOTAL_COUNT}"
  exit 0
else
  echo "ERROR: Todos los backups fallaron"
  exit 1
fi
