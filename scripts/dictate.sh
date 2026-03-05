#!/usr/bin/env bash

# Speech-to-text toggle launcher
# Usage: dictate.sh

# Check if whisper-server is running
if ! systemctl is-active --quiet whisper-server; then
    notify-send --urgency=critical "Voice Dictation" \
        "Whisper server not running"
    exit 1
fi

# Run the speech-to-text toggle script
speech-to-text
