#!/bin/sh
set -eu

TOKEN=x
CHAT_ID=x
IMAGE_PATH="/home/ubuntu/rasp/cameraCheck/test.jpg"
OFFSET=0
IMG="/tmp/capture.jpg"

echo "Listening for /update from chat ${CHAT_ID}..."

while true; do
  RESPONSE=$(curl -s "https://api.telegram.org/bot${TOKEN}/getUpdates?offset=${OFFSET}&timeout=30")
  COUNT=$(echo "$RESPONSE" | jq '.result | length')

  if [[ "$COUNT" -gt 0 ]]; then
    for ((i=0; i<$COUNT; i++)); do
      MSG=$(echo "$RESPONSE" | jq -r ".result[$i].message.text // empty")
      FROM=$(echo "$RESPONSE" | jq -r ".result[$i].message.chat.id // empty")
      UPDATE_ID=$(echo "$RESPONSE" | jq -r ".result[$i].update_id // empty")
      OFFSET=$((UPDATE_ID+1))

      if [[ "$FROM" == "$CHAT_ID" && "$MSG" == "/u" ]]; then
        echo "📸 Capturing image from /dev/video0..."
        curl -s "http://127.0.0.1:8080/?action=snapshot" -o "$IMG"

        echo "➡️ Sending photo to chat..."
        curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendPhoto" \
          -F chat_id="$CHAT_ID" \
          -F photo=@"$IMG" \
          -F caption="Live photo from /dev/video0" >/dev/null
      fi
    done
  fi
done
