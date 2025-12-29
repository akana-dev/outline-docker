ifeq ($(wildcard .env),)
$(shell ip route get 1.1.1.1 | awk '{print "PUBLIC_HOSTNAME="$$7; exit}' > .env)
endif

include .env

install: access.txt
	@echo "✅ Outline Server установлен и запущен!"

init:
	@if [ ! -f .env ]; then \
		echo "❌ .env не найден"; \
		exit 1; \
	fi
	@if ! grep -q "^API_PORT=" .env; then \
		echo "🔄 Запуск инициализации Outline..."; \
		chmod +x ./init/init-outline.sh && ./init/init-outline.sh; \
	else \
		echo "ℹ️ Инициализация уже выполнена"; \
	fi

start: init
	docker compose up -d

access.txt: start
	@echo "⏳ Ожидание готовности сертификата..."
	@for i in $$(seq 1 60); do \
		if [ -f ./data/persisted-state/shadowbox-selfsigned.crt ]; then \
			break; \
		fi; \
		sleep 1; \
	done
	@if [ ! -f ./data/persisted-state/shadowbox-selfsigned.crt ]; then \
		echo "❌ Сертификат не создан за 60 секунд"; \
		docker compose logs shadowbox; \
		exit 1; \
	fi
	@CERT_SHA256=$$(openssl x509 -in ./data/persisted-state/shadowbox-selfsigned.crt -noout -sha256 -fingerprint | sed 's/.*=//' | tr -d ':'); \
	API_URL="https://$(PUBLIC_HOSTNAME):$(API_PORT)/$(SB_API_PREFIX)"; \
	echo "apiUrl:$${API_URL}" > ./data/access.txt; \
	echo "certSha256:$${CERT_SHA256}" >> ./data/access.txt; \
	echo "📄 Конфиг для Outline Manager:"; \
	echo "{\"apiUrl\":\"$${API_URL}\",\"certSha256\":\"$${CERT_SHA256}\"}"
	echo "🔧 Создание keep-alive ключа..."
	curl -sfk "https://localhost:${API_PORT}/${SB_API_PREFIX}/access-keys" -X POST -d '{"name":"keep-alive"}' >/dev/null

restart:
	docker compose down
	make install

update:
	docker compose pull shadowbox
	docker compose up -d

.PHONY: install init start access.txt restart update