# Build stage
FROM alpine:latest AS build
RUN apk add --no-cache git build-base linux-headers libevent-dev libbsd-dev libjpeg-turbo-dev musl-dev
RUN git clone https://github.com/pikvm/ustreamer /tmp/ustreamer
WORKDIR /tmp/ustreamer
RUN make && make install

# Final stage
FROM alpine:latest
RUN apk --no-cache add ffmpeg supervisor font-dejavu py3-opencv jq curl libevent nginx i2c-tools py3-smbus
COPY --from=build /usr/local/bin/ustreamer /usr/local/bin/

#nginx
COPY webpage/ /var/www/html/
COPY nginx-base.conf /etc/nginx/nginx.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy supervisor scripts
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY streamer.sh /usr/local/bin/
COPY recorder.sh /usr/local/bin/
COPY motion_detector.py /usr/local/bin/
COPY telegram_utils.sh /usr/local/bin/
COPY telegram_listener.sh /usr/local/bin/
COPY telegram_send_capture.sh /usr/local/bin/
COPY power_checker.sh /usr/local/bin/
COPY get_hat_data.py /usr/local/bin/

HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost/ || exit 1

EXPOSE 80
EXPOSE 8080
EXPOSE 9001

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]