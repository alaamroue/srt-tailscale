
FROM alpine:latest
RUN apk --no-cache add ffmpeg
#COPY input.mp4 /input.mp4

ENV SRT_PORT=1936
#RUN mkdir -p /recordings
ENTRYPOINT ["/bin/sh", "-c", "while true; do ffmpeg -nostdin -re -i input.mp4 -c copy -f mpegts \"srt://srt-server:${SRT_PORT}?mode=caller\"; sleep 1; done"]