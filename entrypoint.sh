#!/usr/bin/env bash
set -Eeuo pipefail

# TZ
if [ -n "${TZ:-}" ]; then
  ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone || true
fi

# Asegurar log
touch /var/log/backup.log

# Exportar variables para cron (como script "sourceable")
# Solo escribe las que existan
{
  [ -n "${MONGO_URI:-}" ] && echo "export MONGO_URI=\"${MONGO_URI}\""
  [ -n "${MONGO_DBS:-}" ] && echo "export MONGO_DBS=\"${MONGO_DBS}\""
  [ -n "${MONGO_DB:-}" ] && echo "export MONGO_DB=\"${MONGO_DB}\""
  echo "export OUTPUT_DIR=\"${OUTPUT_DIR:-/backups}\""
  echo "export RETENTION_DAYS=\"${RETENTION_DAYS:-0}\""
  [ -n "${BACKUP_PREFIX:-}" ] && echo "export BACKUP_PREFIX=\"${BACKUP_PREFIX}\""
  [ -n "${NOTIFY_ON:-}" ] && echo "export NOTIFY_ON=\"${NOTIFY_ON}\""
  [ -n "${TELEGRAM_TOKEN:-}" ] && echo "export TELEGRAM_TOKEN=\"${TELEGRAM_TOKEN}\""
  [ -n "${TELEGRAM_CHAT_ID:-}" ] && echo "export TELEGRAM_CHAT_ID=\"${TELEGRAM_CHAT_ID}\""
  [ -n "${TZ:-}" ] && echo "export TZ=\"${TZ}\""
  # S3 Configuration
  [ -n "${S3_UPLOAD:-}" ] && echo "export S3_UPLOAD=\"${S3_UPLOAD}\""
  [ -n "${AWS_ACCESS_KEY_ID:-}" ] && echo "export AWS_ACCESS_KEY_ID=\"${AWS_ACCESS_KEY_ID}\""
  [ -n "${AWS_SECRET_ACCESS_KEY:-}" ] && echo "export AWS_SECRET_ACCESS_KEY=\"${AWS_SECRET_ACCESS_KEY}\""
  [ -n "${AWS_DEFAULT_REGION:-}" ] && echo "export AWS_DEFAULT_REGION=\"${AWS_DEFAULT_REGION}\""
  [ -n "${S3_BUCKET:-}" ] && echo "export S3_BUCKET=\"${S3_BUCKET}\""
  [ -n "${S3_PREFIX:-}" ] && echo "export S3_PREFIX=\"${S3_PREFIX}\""
  [ -n "${S3_STORAGE_CLASS:-}" ] && echo "export S3_STORAGE_CLASS=\"${S3_STORAGE_CLASS}\""
  [ -n "${MULTIPART_THRESHOLD:-}" ] && echo "export MULTIPART_THRESHOLD=\"${MULTIPART_THRESHOLD}\""
  [ -n "${KEEP_LOCAL_BACKUP:-}" ] && echo "export KEEP_LOCAL_BACKUP=\"${KEEP_LOCAL_BACKUP}\""
} > /etc/profile.d/backup-env.sh

if [ -n "${CRON_SCHEDULE:-}" ]; then
  echo "Configurando cron con: ${CRON_SCHEDULE}"
  # Importante: en /etc/cron.d la línea requiere USUARIO (root)
  echo "${CRON_SCHEDULE} root . /etc/profile; . /etc/profile.d/backup-env.sh; /app/backup.sh >> /var/log/backup.log 2>&1" > /etc/cron.d/mongo-backup
  chmod 0644 /etc/cron.d/mongo-backup

  # Stream de logs al stdout del contenedor
  tail -F /var/log/backup.log &
  echo "Iniciando cron en foreground..."
  exec cron -f
else
  echo "CRON_SCHEDULE vacío. Ejecutando backup único..."
  exec /app/backup.sh
fi
