#!/bin/sh
set -eu

echo "Starting backup_archive.sh..."

IP=$(getent hosts srt-client-1 | awk '{print $1}')
echo "Client IP resolved to: $IP"

mkdir -p $SERVER_RECORD_DIR

echo "Starting rclone sync from client to server directory..."
rclone sync     :http: $SERVER_RECORD_DIR \
                --http-url "http://$IP/videos/" \
                --min-age 1m \
                --transfers 4 \
                --checkers 8 \
                --log-file /var/log/rclone-pi.log \
                --log-level INFO
echo "rclone sync completed."
