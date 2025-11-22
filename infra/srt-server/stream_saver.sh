#!/bin/sh
set -eu

ffmpeg \
  -fflags nobuffer \
  -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 2 \
  -use_wallclock_as_timestamps 1 \
  -i "http://srt-client:8080/?action=stream" \
  -c:v copy \
  -f segment \
  -segment_time 60 \
  -reset_timestamps 1 \
  -strftime 1 \
  "recordings/stream_%Y-%m-%d_%H-%M-%S.mkv"