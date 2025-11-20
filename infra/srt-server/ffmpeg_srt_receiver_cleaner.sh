#!/bin/sh
#
# archive_cleaner.sh
#
# Environment variables:
#   SERVER_RETENTION_PERIOD  – seconds (age limit before deletion)
#   CLEANER_INTERVAL  – seconds between cleanup cycles (optional, default: 300)
#

set -eu

: "${SERVER_RETENTION_PERIOD:?SERVER_RETENTION_PERIOD must be set (seconds, e.g. 86400)}"

# Validate numeric
case "$SERVER_RETENTION_PERIOD" in
    ""|*[!0-9]*) echo "SERVER_RETENTION_PERIOD must be numeric seconds." >&2; exit 1 ;;
esac

CLEANER_INTERVAL="${CLEANER_INTERVAL:-300}"

echo "archive_cleaner.sh starting..."
echo "  Monitoring: /archive"
echo "  Removing files older than $SERVER_RETENTION_PERIOD seconds"
echo "  Cleanup cycle: every $CLEANER_INTERVAL seconds"

while :; do
    CUTOFF_FILE=$(mktemp)
    touch -d "@$(( $(date +%s) - SERVER_RETENTION_PERIOD ))" "$CUTOFF_FILE"

    find "/archive" \
        -type f ! -newer "$CUTOFF_FILE" \
        -print -delete 2>/dev/null

    rm -f "$CUTOFF_FILE"

    echo "Cleanup run at $(date)."

    sleep "$CLEANER_INTERVAL"
done
