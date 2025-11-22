#!/bin/sh
set -eu

echo "Starting archive_syncer.sh..."

#IP=$(getent hosts srt-client | awk '{print $1}')
#echo "Client IP resolved to: $IP"

echo "Starting rclone sync from client to server directory..."
rclone sync     :http: /archive \
                --http-url "http://srt-client/archive/" \
                --max-age 1d \
                --transfers 4 \
                --checkers 8 \
                --log-file /var/log/rclone-pi.log \
                --log-level INFO
echo "rclone sync completed."
