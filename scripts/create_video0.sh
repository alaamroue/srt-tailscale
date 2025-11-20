#!/usr/bin/env bash
set -Eeuo pipefail

sudo modprobe -r v4l2loopback

sudo modprobe v4l2loopback \
    video_nr=0 \
    card_label="FakeCam" \
    exclusive_caps=1 \
    max_buffers=4 # Needs to be four due to NB_BUFFER in inputvc

ffmpeg -re -f lavfi -i testsrc=size=640x480:rate=30:decimals=3 \
    -vcodec mjpeg -q:v 5 -f v4l2 /dev/video0 \
    > /dev/null 2>&1 &
