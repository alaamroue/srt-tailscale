#!/bin/sh
set -eu

# Bot setup guide:
# Send /newbot telegram message to @BotFather
# Name the bot and get token
# Start convo with bot
# Do: curl "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getUpdates";
#   to get the chat id

# Variable Setup

: "${TELEGRAM_TOKEN:?Please export TELEGRAM_TOKEN=your_telegram_bot_token}"
: "${TELEGRAM_CHAT_ID:?Please export TELEGRAM_CHAT_ID=your_telegram_chat_id}"

API_URL="https://api.telegram.org/bot${TELEGRAM_TOKEN}"
CONFIG_FILE="/home/ubuntu/srt-tailscale/infra/srt-client/motion_detector_config.txt"
STREAM_URL="http://srt-client/stream"

# Setup
echo "" >${TELEGRAM_CHAT_ID}.state

# Helpers
set_state() {
	echo "$1" >"${TELEGRAM_CHAT_ID}.state"
}

get_state() {
	cat "${TELEGRAM_CHAT_ID}.state"
}

clear_state() {
	echo "" >"${TELEGRAM_CHAT_ID}.state"
}

get_config() {
	var=$1
	awk -F'=' -v k="$var" '
        $1 == k {
            print $2
            exit
        }
    ' "$CONFIG_FILE"
}

set_config() {
	var=$1
	val=$2

	if grep -q "^$var=" "$CONFIG_FILE"; then
		tmp="${CONFIG_FILE}.tmp.$$"
		sed "s|^$var=.*|$var=$val|" "$CONFIG_FILE" >"$tmp" &&
			cat "$tmp" >"$CONFIG_FILE" &&
			rm -f "$tmp"
	fi
}

send_message() {
	text=$(printf '%b' "$1") # turns \n into actual newlines
	reply_markup="${2-}"

	if [ -n "$reply_markup" ]; then
		curl -s -X POST "$API_URL/sendMessage" \
			-d "chat_id=${TELEGRAM_CHAT_ID}" \
			--data-urlencode "text=${text}" \
			-d "parse_mode=Markdown" \
			--data-urlencode "reply_markup=${reply_markup}" \
			>/dev/null
	else
		curl -s -X POST "$API_URL/sendMessage" \
			-d "chat_id=${TELEGRAM_CHAT_ID}" \
			--data-urlencode "text=${text}" \
			-d "parse_mode=Markdown" \
			>/dev/null
	fi
}

answer_callback() {
	callback_id="$1"
	text="${2-}"
	curl -s -X POST "$API_URL/answerCallbackQuery" \
		-d "callback_query_id=${callback_id}" \
		--data-urlencode "text=${text}" \
		>/dev/null
}

send_options_menu() {
	markup='{
    "inline_keyboard":[
      [
        {"text":"📺 Stream","callback_data":"STREAM"},
        {"text":"📸 Capture","callback_data":"CAPTURE"}
      ],
      [
        {"text":"📖 Read config","callback_data":"GET_CONFIG"},
        {"text":"⚙️ Set config","callback_data":"SET_MENU"}
      ]
    ]
  }'

	send_message "Choose an action:" "$markup"
}

send_stream_link() {
	send_message "🌐Here is the stream link: $STREAM_URL"
}

reset_config() {
	send_message "Reseting Config..."
	set_config THRESHOLD_VALUE 15
	set_config COOLDOWN_SECONDS 1.2
	set_config MIN_MOTION_AREA 80
	set_config MOTION_FRAMES_REQUIRED 2
	set_config BACKGROUND_LEARNING_RATE 0.02
	set_config FRAME_WIDTH 640
}

send_current_config() {
	msg="$(
		cat <<EOF
Current options:
- ⚖️ THRESHOLD\_VALUE: $(get_config "THRESHOLD_VALUE")
- ⏱️ COOLDOWN\_SECONDS: $(get_config "COOLDOWN_SECONDS")
- 📏 MIN\_MOTION\_AREA: $(get_config "MIN_MOTION_AREA")
- 🎞️ MOTION\_FRAMES\_REQUIRED: $(get_config "MOTION_FRAMES_REQUIRED")
- 🧠 BACKGROUND\_LEARNING\_RATE: $(get_config "BACKGROUND_LEARNING_RATE")
- 📸 FRAME\_WIDTH: $(get_config "FRAME_WIDTH")
EOF
	)"
	send_message "$msg"
}

run_capture() {
	if [ -x "./capture.sh" ]; then
		./telegram_send_capture.sh &
		send_message "Started *capture.sh* ✅"
	else
		send_message "⚠️ *capture.sh* not found or not executable."
	fi
}

send_set_menu() {
	markup='{
    "inline_keyboard":[
      [
        {"text":"THRESHOLD_VALUE","callback_data":"SET_VAR|THRESHOLD_VALUE"},
        {"text":"COOLDOWN_SECONDS","callback_data":"SET_VAR|COOLDOWN_SECONDS"}
      ],
      [
        {"text":"MIN_MOTION_AREA","callback_data":"SET_VAR|MIN_MOTION_AREA"},
        {"text":"MOTION_FRAMES_REQUIRED","callback_data":"SET_VAR|MOTION_FRAMES_REQUIRED"}
      ],
      [
        {"text":"BACKGROUND_LEARNING_RATE","callback_data":"SET_VAR|BACKGROUND_LEARNING_RATE"},
        {"text":"FRAME_WIDTH","callback_data":"SET_VAR|FRAME_WIDTH"}
      ],
      [
        {"text":"Reset Config to default","callback_data":"SET_VAR|RESET_CONFIG"}
      ]
    ]
  }'

	send_message "Which config value do you want to change?" "$markup"
}

send_value_menu() {
	var="$1"

	markup="
  {
    \"inline_keyboard\":
    [
      [
        {\"text\":\"10\",\"callback_data\":\"SET_VAL|$var|10\"},
        {\"text\":\"20\",\"callback_data\":\"SET_VAL|$var|20\"},
        {\"text\":\"30\",\"callback_data\":\"SET_VAL|$var|30\"}
      ],
      [
        {\"text\":\"60\",\"callback_data\":\"SET_VAL|$var|60\"}
      ]
    ]
  }"

	send_message "Choose value for *${var}*:" "$markup"
}

handle_direct_set() {
	text="$1"

	set -- $text
	# $1 is /set
	var="$2"

	if [ $# -lt 3 ]; then
		send_message "No value given for /set. \nUsage example: /set THRESHOLD\_VALUE 20"
		return
	fi
	value="$3"

	if [ -z "${var}" ] || [ -z "${value}" ]; then
		send_message "Usage:\n\`/set CAPTURE\_TIME 20\` or \`/set CAPTURE\_DELAY 10\`"
		return
	fi

	case "$var" in
	THRESHOLD_VALUE | MIN_MOTION_AREA | MOTION_FRAMES_REQUIRED | FRAME_WIDTH)
		case "$value" in
		*[!0-9]* | '')
			send_message "$(printf '%s' "$var" | sed 's/_/\\_/g') must be a *number*."
			return
			;;
		esac
		;;
	COOLDOWN_SECONDS | BACKGROUND_LEARNING_RATE)
		case "$value" in
		*[!0-9.]* | '')
			send_message "$(printf '%s' "$var" | sed 's/_/\\_/g') must be a *float*."
			return
			;;
		esac
		;;
	*)
		send_message "Unknown variable used in /set. \nUsage example: /set THRESHOLD\_VALUE 20"
    return
		;;
	esac

	set_config "$var" "$value"
	reload_config
	send_message "✅ Updated *${var}* to *${value}*"
	send_current_config
}

handle_message_update() {
	update="$1"

	text=$(echo "$update" | jq -r '.message.text // empty')

	if [ -z "$text" ] || [ "$text" = "null" ]; then
		return
	fi

	state=$(get_state)

	if [ -n "$state" ]; then
		OLD_IFS=$IFS
		IFS='|'
		set -- $state
		IFS=$OLD_IFS
		kind="$1"
		var="$2"

		if [ "$kind" = "AWAIT_NUMBER" ]; then
			if [ "$text" = "/cancel" ]; then
				clear_state
				send_message "❌ Cancelled setting *${var}*."
				return
			fi

			case "$text" in
			/*)
				clear_state
				;;
			*)
				value="$text"
				case "$value" in
				*[!0-9.]* | '')
					send_message "Please send a *number* for *${var}*.\nOr type /cancel."
					return
					;;
				esac

				set_config "$var" "$value"
				reload_config
				clear_state
				send_message "✅ Updated *${var}* to *${value}*"
				send_current_config
				return
				;;
			esac
		fi
	fi

	case "$text" in
	"/start" | "/options")
		send_options_menu
		;;
	"/stream" | "/s")
		send_stream_link
		;;
	"/capture" | "/c")
		run_capture
		;;
	"/set")
		send_set_menu
		;;
	/set\ *)
		handle_direct_set "$text"
		;;
	*)
		# Just ignore
		#send_message "I know these commands:\n/options – show buttons\n/stream or /s – stream link\n/capture or /c – run capture.sh\n/set – interactive config menu\n/set VAR VALUE – direct config (e.g. \`/set CAPTURE_TIME 20\`, \`/set CAPTURE_DELAY 10\`)"
		;;
	esac
}

handle_callback_update() {
	update="$1"

	callback_id=$(echo "$update" | jq -r '.callback_query.id')
	data=$(echo "$update" | jq -r '.callback_query.data')

	case "$data" in
	"STREAM")
		send_stream_link
		answer_callback "$callback_id" "Sending stream link…"
		;;
	"CAPTURE")
		run_capture
		answer_callback "$callback_id" "Running capture.sh…"
		;;
	"GET_CONFIG")
		send_current_config
		answer_callback "$callback_id" "Reading config..."
		;;
	"SET_MENU")
		send_set_menu
		answer_callback "$callback_id" ""
		;;
	SET_VAR\|*)
		var=${data#SET_VAR|}

		if [ "$var" = "RESET_CONFIG" ]; then
			answer_callback "$callback_id" "Reseting Config to default..."
			reset_config
			reload_config
			send_current_config
		else
			send_value_menu "$var"
			answer_callback "$callback_id" "Choose a value for ${var}"
		fi
		;;
	SET_VAL\|*)
		rest=${data#SET_VAL|}
		var=${rest%%|*}
		value=${rest##*|}

		set_config "$var" "$value"
		reload_config
		send_message "✅ Updated *${var}* to *${value}*"
		answer_callback "$callback_id" "Saved ${var}=${value}"
		send_current_config
		;;
	*)
		answer_callback "$callback_id" "Unknown action"
		;;
	esac
}

handle_update() {
	update="$1"

	if echo "$update" | jq -e '.message? // empty' >/dev/null; then
		handle_message_update "$update"
	fi

	if echo "$update" | jq -e '.callback_query? // empty' >/dev/null; then
		handle_callback_update "$update"
	fi
}

reload_config() {
	echo "restart supervisor"
}

echo "Bot started. Press Ctrl+C to stop."

LAST_UPDATE_ID=0
while true; do
	response=$(curl -s "$API_URL/getUpdates" \
		-d "timeout=50" \
		-d "offset=$((LAST_UPDATE_ID + 1))") || {
		echo "Failed to getUpdates, retrying in 2s…" >&2
		sleep 2
		continue
	}

	last_id=$(echo "$response" | jq -r 'if (.result | length) > 0 then .result[-1].update_id else empty end')
	if [ -n "$last_id" ] && [ "$last_id" != "null" ]; then
		LAST_UPDATE_ID=$last_id
	fi

	echo "$response" | jq -c '.result[]?' | while IFS= read -r update; do
		[ -z "$update" ] && continue
		handle_update "$update"
	done

done
