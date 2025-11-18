#!/bin/sh
set -eu

ffmpeg  -i "srt://0.0.0.0:$SRT_PORT?mode=listener" \
        -c:v $SERVER_LOCAL_ENCODER \
        -crf $SERVER_LOCAL_ENCODER_CRF \
        -preset $SERVER_LOCAL_ENCODER_PRESET \
        -vf "fps=30" \
        -f segment -segment_time $ARCHIVE_SEGMENT_DURATION -strftime 1 "/recordings/%Y_%m_%d-%H_%M_%S.mp4"