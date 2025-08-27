#!/usr/bin/env bash
set -euo pipefail

LEVEL="${1:-error}"  # error | warn | info
TEXT="${2:-"(sin mensaje)"}"

# Solo Telegram (según lo que pediste)
if [ -n "${TELEGRAM_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
  curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${TEXT}" >/dev/null || true
fi
