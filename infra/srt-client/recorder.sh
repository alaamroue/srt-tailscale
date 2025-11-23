#!/bin/sh
set -eu

START_DATE=$(date +%Y_%m_%d-%H_%M_%S)

ffmpeg \
  -i "http://localhost:8080/?action=stream" \
  -c:v "$CLIENT_LOCAL_ENCODER" \
  -crf "$CLIENT_LOCAL_ENCODER_CRF" \
  -preset "$CLIENT_LOCAL_ENCODER_PRESET" \
  -vf "format=yuv420p,fps=30,drawtext=fontfile=/usr/share/fonts/dejavu/DejaVuSans.ttf:text='%{localtime} UTC':x=W-tw-10:y=10:fontcolor=white:box=1:boxcolor=0x00000099" \
  -hls_time 5 \
  -hls_list_size 17280 \
  -hls_segment_filename "/archive/${START_DATE}_%05d.ts" \
  -hls_flags program_date_time+append_list+omit_endlist+independent_segments+delete_segments \
  -movflags +faststart \
  "/archive/playlist.m3u8"
