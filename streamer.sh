#!/bin/sh
set -eu

exec ustreamer \
	--device=/dev/video0 \
	--host=0.0.0.0 \
	--port=8080 \
	--format=MJPEG \
	-r $CLIENT_STREAM_RESOLUTION