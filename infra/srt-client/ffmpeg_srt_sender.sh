#!/bin/sh
set -eu

ffmpeg -nostdin -re \
  -i "http://localhost:8080/?action=stream" \
  -an -c:v libx264 -preset veryfast -tune zerolatency -pix_fmt yuv420p \
  -f mpegts "srt://srt-server:$SRT_PORT?mode=caller"