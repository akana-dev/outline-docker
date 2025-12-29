#!/bin/bash
set -euo pipefail

command -v docker compose >/dev/null || { echo "❌ docker compose не найден"; exit 1; }
command -v openssl >/dev/null || { echo "❌ openssl не найден"; exit 1; }

if [[ ! -f .env ]]; then
  echo "🔍 Определение публичного IP..."
  if PUBLIC_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}'); then
    echo "✅ Обнаружен публичный IP: $PUBLIC_IP"
    echo "PUBLIC_HOSTNAME=$PUBLIC_IP" > .env
  else
    echo "❌ Не удалось определить публичный IP"
    echo "   Укажите вручную: echo \"PUBLIC_HOSTNAME=ваш.ip\" > .env"
    exit 1
  fi
else
  echo "ℹ️  Файл .env уже существует"
fi

if ! grep -q "^API_PORT=" .env; then
  chmod +x ./init/init-outline.sh
  echo "🔄 Запуск инициализации Outline..."
  ./init/init-outline.sh
else
  echo "ℹ️  Инициализация уже выполнена"
fi

export $(grep -v '^#' .env | xargs)

echo "🐳 Запуск контейнеров..."
docker compose up -d

echo "⏳ Ожидание готовности Outline..."
CERT_FILE="./data/persisted-state/shadowbox-selfsigned.crt"
timeout=60
for ((i=0; i<timeout; i++)); do
  if [[ -f "$CERT_FILE" ]]; then
    break
  fi
  sleep 1
done

if [[ ! -f "$CERT_FILE" ]]; then
  echo "❌ Сертификат не создан. Логи:"
  docker compose logs shadowbox
  exit 1
fi

ACCESS_FILE="./data/access.txt"
if [[ ! -f "$ACCESS_FILE" ]]; then
  echo "✅ Генерация access.txt..."
  CERT_SHA256=$(openssl x509 -in "$CERT_FILE" -noout -sha256 -fingerprint | sed 's/.*=//' | tr -d ':')
  API_URL="https://${PUBLIC_HOSTNAME}:${API_PORT}/${SB_API_PREFIX}"
  cat > "$ACCESS_FILE" <<EOF
apiUrl:${API_URL}
certSha256:${CERT_SHA256}
EOF
  echo "📄 Конфиг для Outline Manager:"
  echo "{\"apiUrl\":\"${API_URL}\",\"certSha256\":\"${CERT_SHA256}\"}"
fi

echo "✅ Готово!"