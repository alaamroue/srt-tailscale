#!/bin/sh
set -eu

# Bot setup guide:
# Send /newbot telegram message to @BotFather
# Name the bot and get token
# Start conversation with bot
# Do: curl "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getUpdates";
#   to get the chat id

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/telegram_utils.sh"

# Setup
echo "" >${TELEGRAM_CHAT_ID}.state

# Helpers
set_state() {
	log DEBUG "set_state: called with $1"
	echo "$1" >"${TELEGRAM_CHAT_ID}.state"
}

get_state() {
	log DEBUG "get_state: called"
	cat -- "${TELEGRAM_CHAT_ID}.state"
}

clear_state() {
	log DEBUG "clear_state: called"
	echo "" >"${TELEGRAM_CHAT_ID}.state"
}

answer_callback() {
	log DEBUG "answer_callback: called"
	callback_id="$1"
	text="${2-}"
	log DEBUG "answer_callback: callback_id: $callback_id, text: $text"
	curl_with_fallback "answerCallbackQuery" \
		-d "callback_query_id=${callback_id}" \
		--data-urlencode "text=${text}" \
		>/dev/null
}

send_options_menu() {
	log DEBUG "send_options_menu: called"
	markup='{
    "inline_keyboard":[
      [
        {"text":"📺 Stream","callback_data":"STREAM"},
        {"text":"📸 Capture","callback_data":"CAPTURE"}
      ],
      [
        {"text":"📖 Read config","callback_data":"GET_CONFIG"},
        {"text":"⚙️ Set config","callback_data":"SET_MENU"}
      ],
      [
        {"text":"🎥🟢 Turn On Stream","callback_data":"ON_STREAM"},
        {"text":"🎥🔴 Turn off Stream","callback_data":"OFF_STREAM"}
      ],
      [
        {"text":"🎯🟢 Turn on motion detection","callback_data":"ON_MOTION"},
        {"text":"🎯🔴 Turn off motion detection","callback_data":"OFF_MOTION"}
      ]
    ]
  }'

	send_message "Choose an action:" "$markup"
}

send_stream_link() {
	log DEBUG "send_stream_link: called"
	#todo: get this passed from host
	send_message "🌐Here is the stream link: http://rasp/stream"
}

reset_config() {
	log DEBUG "reset_config: called"
	send_message "Resetting Config..."
	set_config THRESHOLD_VALUE 25
	set_config COOLDOWN_SECONDS 0.8
	set_config MIN_MOTION_AREA 80
	set_config MOTION_FRAMES_REQUIRED 2
	set_config BACKGROUND_LEARNING_RATE 0.02
	set_config FRAME_WIDTH 640
}

send_current_config() {
	log DEBUG "send_current_config: called"
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
	log DEBUG "run_capture: called"
	if [ -x "$SCRIPT_DIR/telegram_send_capture.sh" ]; then
		log DEBUG "run_capture: $SCRIPT_DIR/telegram_send_capture.sh found. Capturing"
		"$SCRIPT_DIR/telegram_send_capture.sh" "Capture: " &
	else
		log DEBUG "run_capture: {$SCRIPT_DIR}/telegram_send_capture.sh not found."
		send_message "⚠️ *telegram_send_capture.sh* not found or not executable."
	fi
}

send_set_menu() {
	log DEBUG "send_set_menu called"
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
	log DEBUG "send_value_menu called"
	var="$1"
	log DEBUG "send_value_menu called with variable $var"

	v="$(get_config "$var")" # current value
	log DEBUG "send_value_menu called with variable $var, value: $v"
	case $v in
	*.*) # treat as float
		# one decimal place, rounded
		set -- $(awk -v v="$v" 'BEGIN {
            printf "%.1f %.1f %.1f %.1f\n", v/4, v/2, v*2, v*4
        }')
		div4=$1
		div2=$2
		mul2=$3
		mul4=$4
		;;
	*) # treat as int
		# integer arithmetic; truncates toward 0
		div4=$((v / 4))
		div2=$((v / 2))
		mul2=$((v * 2))
		mul4=$((v * 4))
		;;
	esac
	log DEBUG "send_value_menu: Calculated using $v: div4: $div4"
	log DEBUG "send_value_menu: Calculated using $v: div2: $div2"
	log DEBUG "send_value_menu: Calculated using $v: mul2: $mul2"
	log DEBUG "send_value_menu: Calculated using $v: mul4: $mul4"

	markup="
  {
    \"inline_keyboard\":
    [
      [
        {\"text\":\"$div4\",\"callback_data\":\"SET_VAL|$var|$div4\"},
        {\"text\":\"$div2\",\"callback_data\":\"SET_VAL|$var|$div2\"}
      ],
      [
        {\"text\":\"$mul2\",\"callback_data\":\"SET_VAL|$var|$mul2\"},
        {\"text\":\"$mul4\",\"callback_data\":\"SET_VAL|$var|$mul4\"}
      ]
    ]
  }"

	log DEBUG "send_value_menu: markup created. Sending it..."
	send_message "Choose value for *${var}*:" "$markup"
}

handle_direct_set() {
	text="$1"
	log DEBUG "handle_direct_set: Called"

	set -- $text
	# $1 is /set
	var="$2"

	if [ $# -lt 3 ]; then
		log DEBUG "handle_direct_set:with text: $text and no variable so returning"
		send_message "No value given for /set. \nUsage example: /set THRESHOLD\_VALUE 20"
		return
	fi
	value="$3"
	log DEBUG "handle_direct_set:with text: $text and variable: $var and value $value"

	if [ -z "${var}" ] || [ -z "${value}" ]; then
		log DEBUG "handle_direct_set:with empty value so retuning"
		send_message "Usage:\n\`/set CAPTURE\_TIME 20\` or \`/set CAPTURE\_DELAY 10\`"
		return
	fi

	case "$var" in
	THRESHOLD_VALUE | MIN_MOTION_AREA | MOTION_FRAMES_REQUIRED | FRAME_WIDTH)
		log DEBUG "handle_direct_set: Value should be an int"
		case "$value" in
		*[!0-9]* | '')
			log DEBUG "handle_direct_set: Got a non int"
			send_message "$(printf '%s' "$var" | sed 's/_/\\_/g') must be a *number*."
			return
			;;
		esac
		;;
	COOLDOWN_SECONDS | BACKGROUND_LEARNING_RATE)
		log DEBUG "handle_direct_set: Value should be a float"
		case "$value" in
		*[!0-9.]* | '')
			log DEBUG "handle_direct_set: Got a non float"
			send_message "$(printf '%s' "$var" | sed 's/_/\\_/g') must be a *float*."
			return
			;;
		esac
		;;
	*)
		log DEBUG "handle_direct_set: Variable $var is unknown"
		send_message "Unknown variable used in /set. \nUsage example: /set THRESHOLD\_VALUE 20"
		return
		;;
	esac

	log DEBUG "handle_direct_set: All checks passed. Setting $var to $value"
	set_config "$var" "$value"
	reload_config
	send_current_config
}

handle_message_update() {
	log DEBUG "handle_message_update: Called"
	update="$1"

	text=$(echo "$update" | jq -r '.message.text // empty')

	if [ -z "$text" ] || [ "$text" = "null" ]; then
		log DEBUG "handle_message_update: has empty text. Returning..."
		return
	fi

	state=$(get_state)
	log DEBUG "handle_message_update: Text: $text. Current state: $state"

	if [ -n "$state" ]; then
		OLD_IFS=$IFS
		IFS='|'
		set -- $state
		IFS=$OLD_IFS
		kind="$1"
		var="$2"

		log DEBUG "handle_message_update: State: $state. kind: $kind, variable: $var, text: $text"
		if [ "$kind" = "AWAIT_NUMBER" ]; then
			if [ "$text" = "/cancel" ]; then
				log DEBUG "handle_message_update: Got text cancel, so returning..."
				clear_state
				send_message "❌ Cancelled setting *${var}*."
				return
			fi

			case "$text" in
			/*)
				log DEBUG "handle_message_update: Got a command so canceling..."
				clear_state
				;;
			*)
				value="$text"
				case "$value" in
				*[!0-9.]* | '')
					log DEBUG "handle_message_update: Got invalid value: $value so canceling..."
					send_message "Please send a *number* for *${var}*.\nOr type /cancel."
					return
					;;
				esac

				set_config "$var" "$value"
				reload_config
				clear_state
				send_current_config
				return
				;;
			esac
		fi
	fi

	case "$text" in
	"/start" | "/options")
		log DEBUG "handle_message_update: /options requested"
		send_options_menu
		;;
	"/stream" | "/s")
		log DEBUG "handle_message_update: /stream requested"
		send_stream_link
		;;
	"/capture" | "/c")
		log DEBUG "handle_message_update: /capture requested"
		run_capture
		;;
	"/set")
		log DEBUG "handle_message_update: /set requested"
		send_set_menu
		;;
	/set\ *)
		log DEBUG "handle_message_update: /set with values requested"
		handle_direct_set "$text"
		;;
	*)
		log DEBUG "handle_message_update: Got non defined text so ignoring..."
		# Just ignore
		#send_message "I know these commands:\n/options – show buttons\n/stream or /s – stream link\n/capture or /c – run capture.sh\n/set – interactive config menu\n/set VAR VALUE – direct config (e.g. \`/set CAPTURE_TIME 20\`, \`/set CAPTURE_DELAY 10\`)"
		;;
	esac
}

handle_callback_update() {
	log DEBUG "handle_callback_update: Called"
	update="$1"

	callback_id=$(echo "$update" | jq -r '.callback_query.id')
	data=$(echo "$update" | jq -r '.callback_query.data')

	log DEBUG "handle_callback_update: with callback_id: $callback_id, data: $data"
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
	"ON_STREAM")
		stream_on
		answer_callback "$callback_id" ""
		;;
	"OFF_STREAM")
		stream_off
		answer_callback "$callback_id" ""
		;;
	"ON_MOTION")
		motion_detector_on
		answer_callback "$callback_id" ""
		;;
	"OFF_MOTION")
		motion_detector_off
		answer_callback "$callback_id" ""
		;;
	SET_VAR\|*)
		var=${data#SET_VAR|}

		if [ "$var" = "RESET_CONFIG" ]; then
			answer_callback "$callback_id" "Resetting Config to default..."
			reset_config
			reload_config
			send_current_config
		else
			set_state "AWAIT_NUMBER|$var"
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
		answer_callback "$callback_id" "Saved ${var}=${value}"
		send_current_config
		;;
	*)
		answer_callback "$callback_id" "Unknown action"
		;;
	esac
}

handle_update() {
	log DEBUG "handle_update: Called"

	update="$1"

	chat_id=$(echo "$update" | jq -r '.message.chat.id // .callback_query.message.chat.id // empty')
	if [ -z "$chat_id" ] || [ "$chat_id" != "$TELEGRAM_CHAT_ID" ]; then
		log DEBUG "handle_update: Chat id does not match required got $chat_id expected $TELEGRAM_CHAT_ID"
		return
	fi

	if echo "$update" | jq -e '.message? // empty' >/dev/null; then
		log DEBUG "handle_update: message update detected"
		handle_message_update "$update"
	fi

	if echo "$update" | jq -e '.callback_query? // empty' >/dev/null; then
		log DEBUG "handle_update: callback update detected"
		handle_callback_update "$update"
	fi
}

log DEBUG "Bot started."

# Cacher
(
  while :; do
    cache_telegram_ip
    sleep 300  # 300 seconds = 5 minutes
  done
) &

# Main loop
LAST_UPDATE_ID=0
while true; do
	log DEBUG "Main Loop: Checking Updates"
	response=$(
		curl_with_fallback "getUpdates" \
			-f \
			-d "timeout=50" \
			-d "offset=$((LAST_UPDATE_ID + 1))"
	)
	status=$?
	log DEBUG "Main Loop: Checking Updates. curl result is $status"

	case "$status" in
	0) log DEBUG "getUpdates: OK!" ;;
	6) log DEBUG "getUpdates: could not resolve host (DNS problem?)" ;;
	7) log DEBUG "getUpdates: failed to connect to host (connection refused / no route)" ;;
	28) log DEBUG "getUpdates: operation timed out" ;;
	*) log DEBUG "getUpdates: curl error $status" ;;
	esac

	last_id=$(echo "$response" | jq -r 'if (.result | length) > 0 then .result[-1].update_id else empty end')
	log DEBUG "getUpdates: last_id: $last_id"
	if [ -n "$last_id" ] && [ "$last_id" != "null" ]; then
		log DEBUG "getUpdates: setting last update id to $last_id"
		LAST_UPDATE_ID=$last_id
	fi

	echo "$response" | jq -c '.result[]?' | while IFS= read -r update; do
		[ -z "$update" ] && continue
		log DEBUG "Handling update"
		handle_update "$update"
	done

done
