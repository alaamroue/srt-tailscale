#!/bin/sh
#
# record_cleaner.sh
#
# Environment variables:
#   CLIENT_RETENTION_PERIOD  – seconds (age limit before deletion)
#   CLIENT_RECORD_DIR – directory to clean
#   CLIENT_CLEANER_INTERVAL  – seconds between cleanup cycles (optional, default: 300)
#

set -eu

: "${CLIENT_RETENTION_PERIOD:?CLIENT_RETENTION_PERIOD must be set (seconds, e.g. 86400)}"
: "${CLIENT_RECORD_DIR:?CLIENT_RECORD_DIR must be set, e.g. /var/tmp/records}"

# Validate dir
if [ ! -d "$CLIENT_RECORD_DIR" ]; then
    echo "Error: CLIENT_RECORD_DIR '$CLIENT_RECORD_DIR' is not a valid directory." >&2
    exit 1
fi

# Validate numeric
case "$CLIENT_RETENTION_PERIOD" in
    ""|*[!0-9]*) echo "CLIENT_RETENTION_PERIOD must be numeric seconds." >&2; exit 1 ;;
esac

CLIENT_CLEANER_INTERVAL="${CLIENT_CLEANER_INTERVAL:-300}"

echo "record_cleaner.sh starting..."
echo "  Monitoring: $CLIENT_RECORD_DIR"
echo "  Removing files older than $CLIENT_RETENTION_PERIOD seconds"
echo "  Cleanup cycle: every $CLIENT_CLEANER_INTERVAL seconds"

while :; do
    CUTOFF_FILE=$(mktemp)
    touch -d "@$(( $(date +%s) - CLIENT_RETENTION_PERIOD ))" "$CUTOFF_FILE"

    find "$CLIENT_RECORD_DIR" \
        -type f ! -newer "$CUTOFF_FILE" \
        -print -delete 2>/dev/null

    rm -f "$CUTOFF_FILE"

    echo "Cleanup run at $(date)."

    sleep "$CLIENT_CLEANER_INTERVAL"
done
