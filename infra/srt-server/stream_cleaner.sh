#!/bin/sh
set -eu

echo "Starting stream_cleaner.sh..."

python /usr/local/bin/stream_cleaner.py \
  --base-dir /archive/ \
  --live-dir /recordings/ \
  --threshold 300 \
  --playlist-name playlist.m3u8 \
  --delete

sleep 30

echo "stream_cleaner.sh completed."