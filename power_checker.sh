#!/bin/sh
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/telegram_utils.sh"

get_hat_value() {
    if ! output=$(python "$SCRIPT_DIR/get_hat_data.py"); then
        log ERROR "get_hat_data.py failed"
        printf '%s\n' ""
        return 1
    fi

    set -- $output
    printf '%s\n' "${2:-}"
}

get_power_state() {
    value=$1

    case $value in
        ''|*[!0-9.-]*|*.*.*)
            return 1
            ;;
    esac

    # <= 200.0  -> mains
    # >  200.0  -> battery
    awk -v v="$value" '
        BEGIN {
            if (v >= -100.0)
                print "mains";
            else
                print "battery";
        }
    '
}

log DEBUG "Doing initial check"
old_value=$(get_hat_value || true)
old_state=$(get_power_state "$old_value" 2>/dev/null || printf '%s\n' unknown)

while :; do
    log DEBUG "Main Loop: Checking Updates"

    new_value=$(get_hat_value || true)
    new_state=$(get_power_state "$new_value" 2>/dev/null || printf '%s\n' unknown)

    if [ "$new_state" = unknown ]; then
        send_message "⚠️ Unable to determine power/battery status. Please check the HAT and wiring."
    elif [ "$old_state" != "$new_state" ]; then
        if [ "$new_state" = battery ]; then
            send_message "🔋 Power adapter disconnected - device is now running on battery."
        else
            send_message "⚡ Power restored - device is back on mains."
        fi
    fi

    old_state=$new_state
    sleep 10
done
