#!/bin/sh
set -eu

ffmpeg  -nostdin -re \
        -f mpjpeg -i "http://localhost:8080/?action=stream" \
        -c:v libx264 -preset veryfast -tune zerolatency \
        -f mpegts "srt://srt-server:$SRT_PORT?mode=caller"