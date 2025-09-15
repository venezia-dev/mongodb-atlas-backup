#!/usr/bin/env bash
set -euo pipefail

: "${MONGODB_URI:?MONGODB_URI requerido}"

BACKUP_FILE="${1:-}"
TARGET_DB="${2:-}"
SOURCE_DB="${3:-}"

show_usage() {
  cat << EOF
Uso: MONGODB_URI=... ./restore.sh <backup_file> [target_db] [source_db]

Ejemplos:
  # Restaurar backup completo
  ./restore.sh backup_all_20250915_120000.archive.gz

  # Restaurar DB específica a otra DB
  ./restore.sh backup_prod_20250915_120000.archive.gz test prod

  # Restaurar con cambio de namespace
  ./restore.sh backup_prod_20250915_120000.archive.gz prepro prod
EOF
}

if [ -z "$BACKUP_FILE" ]; then
  show_usage
  exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "❌ Archivo no encontrado: $BACKUP_FILE"
  exit 1
fi

echo "🔍 Validando archivo backup..."
if ! mongorestore --archive="$BACKUP_FILE" --gzip --dryRun 2>/dev/null; then
  echo "❌ Archivo no es un archive válido de mongodump"
  exit 1
fi

if [ -n "$TARGET_DB" ] && [ -n "$SOURCE_DB" ]; then
  echo "📋 Modo: Restauración con cambio de namespace"
  echo "📁 Archivo: $BACKUP_FILE"
  echo "📂 Origen: $SOURCE_DB.*"
  echo "🎯 Destino: $TARGET_DB.*"
  
  SAFETY_BACKUP="/tmp/safety_${TARGET_DB}_$(date +'%Y%m%d_%H%M%S').archive.gz"
  echo "💾 Creando backup de seguridad..."
  mongodump --uri="$MONGODB_URI" --db="$TARGET_DB" --archive="$SAFETY_BACKUP" --gzip 2>/dev/null || {
    echo "ℹ️  BD '$TARGET_DB' no existe"
    SAFETY_BACKUP=""
  }
  
  echo "🚀 Ejecutando restauración..."
  if mongorestore \
    --uri="$MONGODB_URI" \
    --archive="$BACKUP_FILE" \
    --gzip \
    --nsFrom="${SOURCE_DB}.*" \
    --nsTo="${TARGET_DB}.*" \
    --drop; then
    
    echo "✅ Restauración exitosa"
    [ -n "$SAFETY_BACKUP" ] && rm -f "$SAFETY_BACKUP"
  else
    echo "❌ Error en restauración"
    if [ -n "$SAFETY_BACKUP" ] && [ -f "$SAFETY_BACKUP" ]; then
      echo "🔄 Restaurando backup de seguridad..."
      mongorestore --uri="$MONGODB_URI" --archive="$SAFETY_BACKUP" --gzip --drop
      rm -f "$SAFETY_BACKUP"
    fi
    exit 1
  fi
  
else
  echo "📋 Modo: Restauración completa"
  echo "📁 Archivo: $BACKUP_FILE"
  echo "⚠️  ADVERTENCIA: Esto sobrescribirá todas las BDs del cluster"
  
  read -p "¿Continuar? (escriba 'SI' para confirmar): " -r
  if [ "$REPLY" != "SI" ]; then
    echo "Operación cancelada"
    exit 0
  fi
  
  echo "🚀 Ejecutando restauración completa..."
  if mongorestore --uri="$MONGODB_URI" --archive="$BACKUP_FILE" --gzip --drop; then
    echo "✅ Restauración completa exitosa"
  else
    echo "❌ Error en restauración completa"
    exit 1
  fi
fi

echo "🎉 ¡Restauración completada!"