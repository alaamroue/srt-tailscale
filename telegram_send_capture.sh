#!/bin/sh
set -eu

MESSAGE=$1

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/telegram_utils.sh"

SNAPSHOT_URL="http://localhost:8080/snapshot"
IMG=/tmp/capture.jpg

log DEBUG "Telegram_send_capture: Called"
if curl -s "$SNAPSHOT_URL" -o "$IMG"; then
	log DEBUG "Telegram_send_capture: Image captured and saved. Sending..."
	curl_with_fallback "sendPhoto" \
		-F chat_id="$TELEGRAM_CHAT_ID" \
		-F photo=@"$IMG" \
		-F caption="$MESSAGE$(date '+%Y-%m-%d %H:%M:%S %Z')"
else
	log DEBUG "Telegram_send_capture: Could not capture image from $SNAPSHOT_URL"
	curl_with_fallback "sendMessage" \
		-d "chat_id=${TELEGRAM_CHAT_ID}" \
		--data-urlencode "text=Could not capture a snapshot! 😞" \
		-d "parse_mode=Markdown"
fi