#!/bin/sh
set -eu

ffmpeg  -i "srt://127.0.0.1:$SRT_PORT?mode=listener" \
        -c:v $SERVER_LOCAL_ENCODER \
        -crf $SERVER_LOCAL_ENCODER_CRF \
        -preset $SERVER_LOCAL_ENCODER_PRESET \
        -vf "fps=30" \
        -f segment -segment_time $ARCHIVE_SEGMENT_DURATION -strftime 1 "/recordings/%Y_%m_%d-%H_%M_%S.mp4"



#ffmpeg \
#  -f lavfi -i testsrc=size=1280x720:rate=30 \
#  -f lavfi -i sine=frequency=1000:sample_rate=48000 \
#  -t 30 \
#  -c:v libx264 -pix_fmt yuv420p \
#  -c:a aac \
#  input.mp4
#
#
#ffmpeg -re -i input.mp4 -f mpegts "srt://srt-client:6000?mode=caller"
#
#ffmpeg -i "srt://0.0.0.0:6000?mode=listener" -c copy -f mpegts alaa.ts
