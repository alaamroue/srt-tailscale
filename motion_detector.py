#!/usr/bin/env python3
import cv2
import numpy as np
import time
import datetime
import os
import subprocess

# Default configuration values
CONFIG_DEFAULTS = {
    "STREAM_URL": "http://localhost:8080/?action=stream",
    "THRESHOLD_VALUE": 8,
    "COOLDOWN_SECONDS": 0.8,
    "MIN_MOTION_AREA": 80,
    "MOTION_FRAMES_REQUIRED": 2,
    "BACKGROUND_LEARNING_RATE": 0.02,
    "FRAME_WIDTH": 640,
    "START_DELAY": 10
}

CONFIG_FILE = "motion_detector_config.txt"


def load_config():
    config = CONFIG_DEFAULTS.copy()

    if os.path.exists(CONFIG_FILE):
        print(f"Loading config from {CONFIG_FILE}...")
        with open(CONFIG_FILE, "r") as f:
            for line in f:
                if "=" in line:
                    key, value = line.strip().split("=", 1)
                    key = key.strip()
                    value = value.strip()
                    if key in config:
                        try:
                            if isinstance(CONFIG_DEFAULTS[key], int):
                                config[key] = int(value)
                            elif isinstance(CONFIG_DEFAULTS[key], float):
                                config[key] = float(value)
                            else:
                                config[key] = value
                        except ValueError:
                            print(f"Warning: Invalid value for {key}, using default.")
    else:
        print(f"No config file found. Using default settings.")

    print("Active configuration:", config)
    return config


def main():
    config = load_config()

    cap = cv2.VideoCapture(config["STREAM_URL"])

    if not cap.isOpened():
        print(f"Error: Could not open video stream: {config['STREAM_URL']}")
        return

    print("Connected to stream (headless mode). Logging motion events...")
    background = None
    motion_counter = 0
    last_motion_time = None
    detector_start_time = datetime.datetime.now()
    print("detector_start_time:", detector_start_time)

    while True:
        ret, frame = cap.read()
        if not ret:
            print("Warning: Failed to read frame... retrying...")
            time.sleep(0.1)
            continue

        height, width = frame.shape[:2]
        if width > config["FRAME_WIDTH"]:
            scale = config["FRAME_WIDTH"] / float(width)
            frame = cv2.resize(frame, (config["FRAME_WIDTH"], int(height * scale)))

        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        gray = cv2.GaussianBlur(gray, (21, 21), 0)

        if background is None:
            background = gray.astype("float")
            continue

        cv2.accumulateWeighted(gray, background, config["BACKGROUND_LEARNING_RATE"])
        bg = cv2.convertScaleAbs(background)

        frame_delta = cv2.absdiff(gray, bg)
        _, thresh = cv2.threshold(frame_delta, config["THRESHOLD_VALUE"], 255, cv2.THRESH_BINARY)
        thresh = cv2.dilate(thresh, None, iterations=2)

        contours, _ = cv2.findContours(
            thresh.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
        )

        motion_detected = any(cv2.contourArea(c) > config["MIN_MOTION_AREA"] for c in contours)

        motion_counter = motion_counter + 1 if motion_detected else 0

        if motion_counter >= config["MOTION_FRAMES_REQUIRED"]:
            now = datetime.datetime.now()
            print("now:", now)
            print("(now - detector_start_time).total_seconds():", (now - detector_start_time).total_seconds())
            if (
                (last_motion_time is None
                or (now - last_motion_time).total_seconds() >= config["COOLDOWN_SECONDS"])
                and (now - detector_start_time).total_seconds() >= config["START_DELAY"]
            ):
                timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                message = f"[{timestamp}] Motion detected"
                subprocess.run(
                    ["sh", "/usr/local/bin/telegram_send_capture.sh", "Motion Detected:"],
                    check=True
                )
                print(message)
                
                last_motion_time = now
            motion_counter = 0

    cap.release()


if __name__ == "__main__":
    main()
