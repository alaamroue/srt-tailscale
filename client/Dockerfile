# Build stage
FROM alpine:latest AS build
RUN apk add --no-cache git build-base cmake linux-headers jpeg-dev
RUN git clone https://github.com/jacksonliam/mjpg-streamer.git
WORKDIR mjpg-streamer/mjpg-streamer-experimental
RUN sed -i 's/v4l2uvc.c)/v4l2uvc.c ..\/..\/utils.c)/' plugins/input_uvc/CMakeLists.txt && \
    sed -i '/#include <linux\/stat.h>/d' utils.c
RUN make && make install

FROM alpine:latest
RUN apk --no-cache add ffmpeg supervisor
COPY --from=build /usr/local/bin/mjpg_streamer /usr/local/bin/
COPY --from=build /usr/local/lib/mjpg-streamer/ /usr/local/lib/mjpg-streamer/
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

VOLUME ["/recordings"]

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]