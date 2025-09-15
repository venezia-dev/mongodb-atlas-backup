#!/usr/bin/env bash
set -euo pipefail

: "${MONGODB_URI:?MONGODB_URI requerido}"
: "${DBS:=}"
: "${DEST_DIR:=/backups}"
: "${RETENTION_DAYS:=7}"
: "${FILE_PREFIX:=backup}"
: "${LOG_DIR:=${DEST_DIR}/logs}"

NOW="$(date +'%Y%m%d_%H%M%S')"
LOG_FILE="${LOG_DIR}/backup_${NOW}.log"

log() {
  local level="$1"
  shift
  local timestamp="$(date +'%Y-%m-%d %H:%M:%S')"
  local message="[$timestamp] [$level] $*"
  echo "$message" | tee -a "$LOG_FILE" >&2
}

log_info() { log "INFO" "$@"; }
log_error() { log "ERROR" "$@"; }
log_warn() { log "WARN" "$@"; }

validate_archive() {
  local archive="$1"
  log_info "Validando integridad: $(basename "$archive")"
  
  if ! [ -f "$archive" ]; then
    log_error "Archivo no encontrado: $archive"
    return 1
  fi
  
  if ! mongorestore --archive="$archive" --gzip --dryRun 2>/dev/null; then
    log_error "Archivo no es un archive válido de mongodump"
    return 1
  fi
  
  log_info "Validación OK: $(basename "$archive")"
  return 0
}

backup_database() {
  local db_name="$1"
  local archive_file="${DEST_DIR}/${FILE_PREFIX}_${db_name}_${NOW}.archive.gz"
  
  log_info "Iniciando backup: $db_name -> $(basename "$archive_file")"
  
  if mongodump --uri="$MONGODB_URI" --db="$db_name" --archive="$archive_file" --gzip; then
    log_info "Dump completado: $db_name"
    
    if validate_archive "$archive_file"; then
      log_info "Backup exitoso: $db_name"
      
      if [[ "${S3_BUCKET:-}" ]]; then
        s3_upload "$archive_file"
      fi
      
      return 0
    else
      rm -f "$archive_file"
      log_error "Backup inválido removido: $db_name"
      return 1
    fi
  else
    log_error "mongodump falló: $db_name"
    return 1
  fi
}

s3_upload() {
  local file="$1"
  local s3_key="${FILE_PREFIX}/$(basename "$file")"
  
  log_info "Subiendo a S3: $s3_key"
  
  if aws s3 cp "$file" "s3://${S3_BUCKET}/$s3_key" --storage-class STANDARD_IA; then
    log_info "S3 upload exitoso: $s3_key"
    if [[ "${KEEP_LOCAL:-true}" == "false" ]]; then
      rm -f "$file"
      log_info "Archivo local eliminado: $(basename "$file")"
    fi
  else
    log_error "S3 upload falló: $s3_key"
    return 1
  fi
}

mkdir -p "$DEST_DIR" "$LOG_DIR"

SUCCESS_COUNT=0
FAILED_COUNT=0

cleanup_old_backups() {
  if [ "$RETENTION_DAYS" -gt 0 ]; then
    log_info "Aplicando retención: $RETENTION_DAYS días"
    find "$DEST_DIR" -type f -name "${FILE_PREFIX}_*.archive.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
  fi
}

main() {
  log_info "=== Iniciando backup MongoDB ==="
  log_info "URI: ${MONGODB_URI%/*}/**"
  log_info "Destino: $DEST_DIR"
  log_info "Retención: $RETENTION_DAYS días"
  
  if [ -n "$DBS" ]; then
    log_info "BDs específicas: $DBS"
    IFS=',' read -ra DB_LIST <<< "$DBS"
    
    for db in "${DB_LIST[@]}"; do
      db=$(echo "$db" | xargs)
      if [ -n "$db" ]; then
        if backup_database "$db"; then
          ((SUCCESS_COUNT++))
        else
          ((FAILED_COUNT++))
        fi
      fi
    done
  else
    log_info "Backup completo del cluster"
    local archive_file="${DEST_DIR}/${FILE_PREFIX}_all_${NOW}.archive.gz"
    
    if mongodump --uri="$MONGODB_URI" --archive="$archive_file" --gzip; then
      log_info "Dump completo exitoso"
      
      if validate_archive "$archive_file"; then
        log_info "Backup completo válido"
        
        if [[ "${S3_BUCKET:-}" ]]; then
          s3_upload "$archive_file"
        fi
        
        ((SUCCESS_COUNT++))
      else
        rm -f "$archive_file"
        log_error "Backup completo inválido"
        ((FAILED_COUNT++))
      fi
    else
      log_error "mongodump completo falló"
      ((FAILED_COUNT++))
    fi
  fi
  
  cleanup_old_backups
  
  log_info "=== Resumen final ==="
  log_info "Exitosos: $SUCCESS_COUNT"
  log_info "Fallidos: $FAILED_COUNT"
  
  if [ $SUCCESS_COUNT -gt 0 ]; then
    log_info "Backup completado con éxito"
    exit 0
  else
    log_error "Todos los backups fallaron"
    exit 1
  fi
}

main "$@"
