#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
cd "$ROOT_DIR"

ENV_FILE=".env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Файл .env не найден. Запустите start.sh"
  exit 1
fi

export $(grep -v '^#' "$ENV_FILE" | xargs)

if [[ -z "${PUBLIC_HOSTNAME:-}" ]]; then
  echo "❌ PUBLIC_HOSTNAME не задан в .env"
  exit 1
fi

STATE_DIR="data/persisted-state"
mkdir -p "$STATE_DIR"
chmod ug+rwx,g+s,o-rwx "$STATE_DIR"

get_random_port() {
  local num=0
  until (( num >= 1024 && num <= 65535 )); do
    num=$(( RANDOM + (RANDOM % 2) * 32768 ))
  done
  echo "$num"
}

API_PORT=$(get_random_port)
KEYS_PORT=$(get_random_port)
while [[ "$KEYS_PORT" == "$API_PORT" ]]; do
  KEYS_PORT=$(get_random_port)
done

SB_API_PREFIX=$(head -c 16 /dev/urandom | base64 -w 0 | tr '/+' '_-' | sed 's/=*$//')

CERT_PATH="$STATE_DIR/shadowbox-selfsigned"
openssl req -x509 -nodes -days 36500 -newkey rsa:4096 \
  -subj "/CN=${PUBLIC_HOSTNAME}" \
  -keyout "${CERT_PATH}.key" -out "${CERT_PATH}.crt" >/dev/null 2>&1

cat > "$STATE_DIR/shadowbox_server_config.json" <<EOF
{
  "hostname": "${PUBLIC_HOSTNAME}",
  "portForNewAccessKeys": ${KEYS_PORT}
EOF

if [[ -n "${SB_DEFAULT_SERVER_NAME:-}" ]]; then
  echo ",\"name\": \"${SB_DEFAULT_SERVER_NAME}\"" >> "$STATE_DIR/shadowbox_server_config.json"
fi

echo "}" >> "$STATE_DIR/shadowbox_server_config.json"

cat >> "$ENV_FILE" <<EOF

# Сгенерировано автоматически init/init-outline.sh
API_PORT=$API_PORT
KEYS_PORT=$KEYS_PORT
SB_API_PREFIX=$SB_API_PREFIX
CERT_FILE=/opt/outline/persisted-state/shadowbox-selfsigned.crt
KEY_FILE=/opt/outline/persisted-state/shadowbox-selfsigned.key
EOF

echo "✅ Порты назначены: API=$API_PORT, Keys=$KEYS_PORT"