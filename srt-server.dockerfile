# build stage
FROM alpine:latest AS build
RUN apk add --no-cache git cmake linux-headers alpine-sdk  tcl openssl-dev zlib-dev
RUN git clone https://github.com/Haivision/srt.git /tmp/srt
WORKDIR /tmp/srt
RUN ./configure && make -j8 && make install

# final stage
FROM alpine:latest
RUN apk add libstdc++
COPY --from=build /usr/local/bin/srt-* /usr/local/bin/
COPY --from=build /usr/local/lib/libsrt* /usr/local/lib/
RUN echo "Hello"

ENV SRT_PORT=1936
RUN mkdir -p /recordings
ENTRYPOINT ["/bin/sh", "-c", "srt-live-transmit srt://:${SRT_PORT}?mode=listener file://con > /recordings/stream.ts"]