.PHONY: init start

init:
	./init/init-outline.sh

start: init
	set -a; source .env.generated; set +a; \
	docker compose up -d

access.txt: start
	@if [ ! -f ./data/persisted-state/shadowbox-selfsigned.crt ]; then \
		echo "❌ Сертификат не готов"; exit 1; \
	fi
	openssl x509 -in ./data/persisted-state/shadowbox-selfsigned.crt -noout -sha256 -fingerprint | sed 's/.*=//' | tr -d ':' > /tmp/cert.sha256
	set -a; source .env.generated; set +a; \
	echo "apiUrl:https://$$PUBLIC_HOSTNAME:$$API_PORT/$$SB_API_PREFIX" > ./data/access.txt
	echo "certSha256:$$(cat /tmp/cert.sha256)" >> ./data/access.txt
	@echo "✅ access.txt создан"

all: access.txt