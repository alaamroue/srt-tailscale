#!/bin/sh
set -eu

TELEGRAM_IP_CACHE="/telegram_ip_cache.txt"
use_cached_telegram_ip() {
	echo "[DEBUG] Using cached Telegram ip"

	if [ -s "$TELEGRAM_IP_CACHE" ]; then
		echo "[DEBUG] Found cached Telegram ip file"
		IFS= read -r ip <"$TELEGRAM_IP_CACHE" || return 0
		echo "[DEBUG] Read ip from $TELEGRAM_IP_CACHE as: $ip"
		if [ -n "$ip" ]; then
			API_URL="https://${ip}/bot${TELEGRAM_TOKEN}"
		fi
	fi
}

send_with_fallback() {
	endpoint=$1
	shift

	if ! curl -s -X POST "$API_BASE/$endpoint" "$@" >/dev/null; then
		use_cached_telegram_ip

		if [ -n "${API_URL:-}" ]; then
			curl -s -X POST "$API_URL/$endpoint" "$@" >/dev/null || return 1
		else
			return 1
		fi
	fi
}

MESSAGE="$1"

API_BASE="https://api.telegram.org/bot${TELEGRAM_TOKEN}"

IMG=/tmp/capture.jpg

echo "[DEBUG] Send capture called"
if curl -s "http://localhost:8080/snapshot" -o "$IMG"; then
	if ! send_with_fallback "sendPhoto" \
		-F chat_id="$TELEGRAM_CHAT_ID" \
		-F photo=@"$IMG" \
		-F caption="$MESSAGE$(date '+%Y-%m-%d %H:%M:%S %Z')"
	then
		echo "[DEBUG] Got img but failed to send"
	fi
else
	echo "[DEBUG] Could not get image"
	send_with_fallback "sendMessage" \
		-d "chat_id=${TELEGRAM_CHAT_ID}" \
		--data-urlencode "text=Could not capture a snapshot! 😞" \
		-d "parse_mode=Markdown"
	
fi