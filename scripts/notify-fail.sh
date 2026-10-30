#!/usr/bin/env bash
# Send failure notice via ~/.config/alert-bot/env if present; else no-op.
set -euo pipefail
MSG=${1:-"proxy-rules build failed"}
ENVF="${HOME}/.config/alert-bot/env"
if [[ ! -f "$ENVF" ]]; then
  echo "[notify] no alert-bot env; skip" >&2
  exit 0
fi
# shellcheck disable=SC1090
set -a; source "$ENVF"; set +a
if [[ -z "${ALERT_BOT_TOKEN:-}" || -z "${ALERT_CHAT_ID:-}" ]]; then
  echo "[notify] alert-bot incomplete; skip" >&2
  exit 0
fi
curl -fsS --max-time 15 -X POST "https://api.telegram.org/bot${ALERT_BOT_TOKEN}/sendMessage" \
  -d chat_id="${ALERT_CHAT_ID}" \
  --data-urlencode "text=${MSG}" >/dev/null || echo "[notify] telegram send failed" >&2
