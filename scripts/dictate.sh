#!/usr/bin/env bash

# Speech-to-text toggle launcher
# Usage: dictate.sh

SCRIPT_DIR="/etc/nixos/scripts"
PYTHON_SCRIPT="$SCRIPT_DIR/speech-to-text.py"

# Check if whisper model exists
MODEL_DIR="/etc/nixos/models"
if [[ ! -d "$MODEL_DIR" ]] || [[ -z "$(ls -A "$MODEL_DIR"/*.bin 2>/dev/null)" ]]; then
    notify-send --urgency=critical "Voice Dictation" "No Whisper models found. Run 'setup-whisper-models' first."
    exit 1
fi

# Run the Python script
python3 "$PYTHON_SCRIPT"