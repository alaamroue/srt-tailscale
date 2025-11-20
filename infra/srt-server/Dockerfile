# Build stage
FROM alpine:latest AS build
RUN apk add --no-cache git cmake linux-headers alpine-sdk  tcl openssl-dev zlib-dev
RUN git clone https://github.com/Haivision/srt.git /tmp/srt
WORKDIR /tmp/srt
RUN ./configure && make -j8 && make install

# Final stage
FROM alpine:latest
RUN apk --no-cache add ffmpeg supervisor rclone
COPY --from=build /usr/local/bin/srt-* /usr/local/bin/
COPY --from=build /usr/local/lib/libsrt* /usr/local/lib/

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY ffmpeg_srt_receiver.sh /usr/local/bin/
COPY backup_archive.sh /usr/local/bin/
COPY archive_cleaner.sh /usr/local/bin/

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]