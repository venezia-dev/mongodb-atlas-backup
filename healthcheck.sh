#!/usr/bin/env bash
set -euo pipefail

: "${HEALTH_MAX_AGE_MIN:=6}"
: "${ALERT_HEALTH:=1}"
: "${ALERT_COOLDOWN_MIN:=60}"

ALERT_FLAG="/app/.alert_sent"

error_and_notify() {
  local msg="$1"
  # notificar solo si está habilitado y respetando cooldown
  if [ "${ALERT_HEALTH}" = "1" ]; then
    if [ ! -f "$ALERT_FLAG" ] || find "$ALERT_FLAG" -mmin +${ALERT_COOLDOWN_MIN} | grep -q . ; then
      /app/notify.sh error "🚨 Healthcheck FAILED $(date -Is)
${msg}" || true
      date -Is > "$ALERT_FLAG"
    fi
  fi
  echo "$msg" >&2
  exit 1
}

# 1) cron vivo
if ! pgrep cron >/dev/null 2>&1; then
  error_and_notify "cron no está corriendo en el contenedor."
fi

# 2) existencia y frescura del último éxito
if [ ! -f /app/last_success.txt ]; then
  # Si nunca hubo un backup exitoso, solo reportar como warning sin notificar
  echo "Esperando primer backup exitoso..."
  exit 0
fi

# ¿último OK demasiado viejo?
if ! find /app/last_success.txt -mmin -${HEALTH_MAX_AGE_MIN} | grep -q . ; then
  # armar detalle con timestamp del último ok
  LAST_OK="$(cat /app/last_success.txt || true)"
  error_and_notify "último backup OK demasiado viejo (> ${HEALTH_MAX_AGE_MIN} min).
Último OK: ${LAST_OK}"
fi

# Si llegamos acá, todo bien: limpiar flag para permitir futuras alertas
[ -f "$ALERT_FLAG" ] && rm -f "$ALERT_FLAG" || true
