#!/bin/sh
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/telegram_utils.sh"

sign() {
    value=${1:-}

    case $value in
        ""|*[!0-9.-]*) echo 0 ;;
        -0|-0.*|0|0.*) echo 0 ;;
        -*)            echo -1 ;;
        *)             echo 1 ;;
    esac
}

get_hat_value() {
    if ! output=$(python3 "$SCRIPT_DIR/get_hat_data.py"); then
        log ERROR "get_hat_data.py failed"
        printf '%s\n' ""
        return 1
    fi

    set -- $output
    printf '%s\n' "${1:-}"
}

log DEBUG "Doing initial check"
value=$(get_hat_value || true)
old_sign=$(sign "$value")

while :; do
    log DEBUG "Main Loop: Checking Updates"

    value=$(get_hat_value || true)
    new_sign=$(sign "$value")

    if [ "$new_sign" -eq 0 ]; then
        send_message "⚠️ Unable to determine power/battery status. Please check the HAT and wiring."
    elif [ "$old_sign" -ne 0 ] && [ "$new_sign" -ne 0 ] && [ "$old_sign" -ne "$new_sign" ]; then
        if [ "$new_sign" -eq -1 ]; then
            send_message "🔋 Power adapter disconnected - device is now running on battery."
        else
            send_message "⚡ Power restored - device is back on mains."
        fi
    fi

    old_sign=$new_sign
    sleep 10
done