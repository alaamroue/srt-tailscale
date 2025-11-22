# Build stage
FROM alpine:latest AS build
RUN apk add --no-cache git build-base cmake linux-headers jpeg-dev
RUN git clone https://github.com/jacksonliam/mjpg-streamer.git /tmp/mjpg-streamer
WORKDIR /tmp/mjpg-streamer/mjpg-streamer-experimental
RUN sed -i 's/v4l2uvc.c)/v4l2uvc.c ..\/..\/utils.c)/' plugins/input_uvc/CMakeLists.txt && \
    sed -i '/#include <linux\/stat.h>/d' utils.c
RUN make && make install

# Final stage
FROM alpine:latest
RUN apk --no-cache add ffmpeg supervisor font-dejavu py3-opencv jq curl
COPY --from=build /usr/local/bin/mjpg_streamer /usr/local/bin/
COPY --from=build /usr/local/lib/mjpg-streamer/ /usr/local/lib/mjpg-streamer/

# Copy supervisor scripts
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY streamer.sh /usr/local/bin/
COPY recorder.sh /usr/local/bin/
COPY motion_detector.py /usr/local/bin/
COPY telegram_listener.sh /usr/local/bin/
COPY telegram_send_capture.sh /usr/local/bin/

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]