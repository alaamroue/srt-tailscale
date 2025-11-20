#!/bin/sh
set -eu

mjpg_streamer   -i "input_uvc.so -d /dev/video0 \
                -r $CLIENT_STREAM_RESOLUTION \
                -f 30" \
                -o "output_http.so -w ./www -p 8080"