#!/bin/sh
set -eu

ffmpeg  -i "http://localhost:8080/?action=stream" \
        -c:v $CLIENT_LOCAL_ENCODER \
        -crf $CLIENT_LOCAL_ENCODER_CRF \
        -preset $CLIENT_LOCAL_ENCODER_PRESET \
        -vf "fps=30,drawtext=fontfile=/usr/share/fonts/dejavu/DejaVuSans.ttf: \
        text='%{localtime}': \
        x=W-tw-10: y=10: \
        fontcolor=white: box=1: boxcolor=0x00000099" \
        -reset_timestamps 1 \
        -movflags +faststart \
        -f segment \
        -segment_time $ARCHIVE_SEGMENT_DURATION \
        -strftime 1 \
        "$CLIENT_RECORD_DIR/%Y_%m_%d-%H_%M_%S.mp4"