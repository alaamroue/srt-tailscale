#!/bin/sh
set -eu

MESSAGE="$1"

API_BASE="https://api.telegram.org/bot${TELEGRAM_TOKEN}"

IMG=/tmp/capture.jpg
curl -s "http://srt-client:8080/snapshot" -o "$IMG" &&
	curl -s -X POST "$API_BASE/sendPhoto" \
		-F chat_id="$TELEGRAM_CHAT_ID" \
		-F photo=@"$IMG" \
		-F caption="$MESSAGE$(date '+%Y-%m-%d %H:%M:%S %Z')" >/dev/null ||
	curl -s -X POST "$API_BASE/sendMessage" \
		-d "chat_id=${TELEGRAM_CHAT_ID}" \
		--data-urlencode "text=Could not capture a snapshot! 😞" \
		-d "parse_mode=Markdown" \
		>/dev/null
