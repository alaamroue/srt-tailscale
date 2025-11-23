#!/bin/sh
set -eu

##### -------------- Checks -------------- #####
command -v supervisorctl >/dev/null 2>&1 || {
	echo "supervisorctl not found" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || {
	echo "jq not defined" >&2; exit 1; }


##### -------------- Logger -------------- #####

log() {
	level=$1
	shift
	echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" >&2
}


##### -------------- Safe curl -------------- #####
TELEGRAM_IPV4_IP="149.154.167.220"

TELEGRAM_MAIN_HOST="api.telegram.org"
API_URL="https://${TELEGRAM_MAIN_HOST}/bot${TELEGRAM_TOKEN}"
TELEGRAM_IP_CACHE="/telegram_ip_cache.txt"


curl_with_fallback() {
	log DEBUG "curl_with_fallback: Called"
	endpoint=$1
	log DEBUG "curl_with_fallback: Endpoint: $endpoint"
	shift

	log DEBUG "curl_with_fallback: Running curl without resolve"
	if response=$(
		curl -sS -X POST "$API_URL/$endpoint" \
        	--connect-timeout 1 \
        	--retry 1 \
        	"$@" 
    ); then
		log DEBUG "curl_with_fallback: Running curl without resolve. Success!"
        printf '%s\n' "$response"
        return 0
    fi

	log DEBUG "curl_with_fallback: Running curl with resolve."
    if response=$(
		curl -sS -X POST "$API_URL/$endpoint" \
        	--connect-timeout 10 \
        	--resolve "${TELEGRAM_MAIN_HOST}:443:$(get_cached_telegram_ip)" \
        	"$@"
    ); then
		log DEBUG "curl_with_fallback: Running curl with resolve. Success!"
        printf '%s\n' "$response"
        return 0
    fi

	log DEBUG "curl_with_fallback: Running curl with ipv4 ip."
    if response=$(
		curl -sS -X POST "$API_URL/$endpoint" \
        	--connect-timeout 10 \
        	--resolve "${TELEGRAM_MAIN_HOST}:443:$TELEGRAM_IPV4_IP" \
        	"$@"
    ); then
		log DEBUG "curl_with_fallback: Running curl with resolve. Success!"
        printf '%s\n' "$response"
        return 0
    fi

	log DEBUG "curl_with_fallback: Running curl without resolve again"
	if response=$(
		curl -sS -X POST "$API_URL/$endpoint" \
        	--connect-timeout 1 \
        	--retry 4 \
        	"$@" 
    ); then
		log DEBUG "curl_with_fallback: Running curl without resolve again. Success!"
        printf '%s\n' "$response"
        return 0
    fi

    log DEBUG "curl_with_fallback: Both attempts failed."
    return 1
}

get_cached_telegram_ip() {
	log DEBUG "get_cached_telegram_ip: Called"
    if [ -n "$TELEGRAM_IP_CACHE" ] && [ -r "$TELEGRAM_IP_CACHE" ]; then
        ip=$(sed -n '1p' "$TELEGRAM_IP_CACHE" 2>/dev/null)
        if [ -n "$ip" ]; then
			log DEBUG "get_cached_telegram_ip: Returning ip: $ip"
            echo "$ip"
            return 0
        fi
    fi

	log DEBUG "get_cached_telegram_ip: Problem reading ip. Returning default"
    echo $TELEGRAM_IPV4_IP
}

cache_telegram_ip() {
	log DEBUG "cache_telegram_ip: Called"
	ip=$(getent hosts "$TELEGRAM_MAIN_HOST" 2>/dev/null | awk '{print $1; exit}') || return 1
	[ -n "$ip" ] || return 1
	log DEBUG "cache_telegram_ip: Cached ip $ip into $TELEGRAM_IP_CACHE"
	echo "$ip" >"$TELEGRAM_IP_CACHE"
}

##### -------------- Telegram communication -------------- #####

send_message() {
	log DEBUG "send_message: called"
	text=$(printf '%b' "$1") # turns \n into actual newlines
	reply_markup="${2-}"

	log DEBUG "send_message: Sending message to chat: $TELEGRAM_CHAT_ID"
	if [ -n "$reply_markup" ]; then
		curl_with_fallback "sendMessage" \
			-d "chat_id=${TELEGRAM_CHAT_ID}" \
			--data-urlencode "text=${text}" \
			-d "parse_mode=Markdown" \
			--data-urlencode "reply_markup=${reply_markup}" \
			>/dev/null
	else
		curl_with_fallback "sendMessage" \
			-d "chat_id=${TELEGRAM_CHAT_ID}" \
			--data-urlencode "text=${text}" \
			-d "parse_mode=Markdown" \
			>/dev/null
	fi
}

##### -------------- Supervisor control -------------- #####
supervisor_state() {
    # $1 = program name
    supervisorctl status "$1" 2>/dev/null | awk 'NR==1 {print $2}'
}

supervisor_manage() {
    prog=$1
    action=$2
    msg_now=$3
    msg_already=$4

    state=$(supervisor_state "$prog")

    if [ -z "$state" ]; then
        send_message "⚠️ Could not determine status of $prog."
        return 1
    fi

    case "$action" in
        start)
            case "$state" in
                RUNNING|STARTING)
                    [ -n "$msg_already" ] && send_message "$msg_already"
                    return 0
                    ;;
                *)
                    if supervisorctl start "$prog"; then
                        [ -n "$msg_now" ] && send_message "$msg_now"
                        return 0
                    else
                        send_message "⚠️ Failed to start $prog."
                        return 1
                    fi
                    ;;
            esac
            ;;

        stop)
            case "$state" in
                STOPPED|EXITED|FATAL|UNKNOWN)
                    [ -n "$msg_already" ] && send_message "$msg_already"
                    return 0
                    ;;
                *)
                    if supervisorctl stop "$prog"; then
                        [ -n "$msg_now" ] && send_message "$msg_now"
                        return 0
                    else
                        send_message "⚠️ Failed to stop $prog."
                        return 1
                    fi
                    ;;
            esac
            ;;

        restart)
            if supervisorctl restart "$prog"; then
                [ -n "$msg_now" ] && send_message "$msg_now"
                return 0
            else
                send_message "⚠️ Failed to restart $prog."
                return 1
            fi
            ;;
    esac
}

reload_config() {
    log DEBUG "reload_config: called"
    supervisor_manage motion_detector restart \
        "🔄 Restarting motion detector…" \
        ""  # no "already" case for restart
}

motion_detector_off() {
    log DEBUG "motion_detector_off: called"
    supervisor_manage motion_detector stop \
        "🛑 Motion detection is now OFF." \
        "🛑 Motion detection was already OFF."
}

motion_detector_on() {
    log DEBUG "motion_detector_on: called"
    supervisor_manage motion_detector start \
        "🎯 Motion detection is now ON!" \
        "🎯 Motion detection was already ON."
}

stream_on() {
    log DEBUG "stream_on: called"
    supervisor_manage streamer start \
        "📹 Live stream activated!" \
        "📹 Live stream was already active."
}

stream_off() {
    log DEBUG "stream_off: called"
    supervisor_manage streamer stop \
        "🚫 Live stream stopped." \
        "🚫 Live stream was already stopped."
}


##### -------------- Config control -------------- #####

CONFIG_FILE="/motion_detector_config.txt"
get_config() {
	log DEBUG "get_config: called"
	var=$1
	log DEBUG "get_config: Variable: $var"
	awk -F'=' -v k="$var" '
        $1 == k {
            print $2
            exit
        }
    ' "$CONFIG_FILE"
}

set_config() {
	log DEBUG "set_config: called"
	var=$1
	val=$2
	log DEBUG "set_config: Variable: $var, Value: $val"

	current_val="$(get_config "$var")"
	if [ "$current_val" != "$val" ]; then
		send_message "⚙️ *${var}* changed: *${current_val}* → *${val}*"
		if grep -q "^$var=" "$CONFIG_FILE"; then
			tmp="${CONFIG_FILE}.tmp.$$"
			sed "s|^$var=.*|$var=$val|" "$CONFIG_FILE" >"$tmp" &&
				cat "$tmp" >"$CONFIG_FILE" &&
				rm -f "$tmp"
		fi
	fi
}