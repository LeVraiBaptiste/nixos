#!/usr/bin/env bash

# Speech-to-text toggle launcher
# Usage: dictate [raw|llm]

MODE="${1:-raw}"

# Check if whisper-server is running
if ! systemctl is-active --quiet whisper-server; then
    notify-send --urgency=critical "Voice Dictation" \
        "Whisper server not running"
    exit 1
fi

# Check if ollama is running for LLM mode
if [ "$MODE" = "llm" ]; then
    if ! systemctl is-active --quiet ollama; then
        notify-send --urgency=critical "Voice Dictation" \
            "Ollama server not running"
        exit 1
    fi
fi

# Run the speech-to-text toggle script
speech-to-text "$MODE"
