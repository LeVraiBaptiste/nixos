#!/usr/bin/env bash

set -e

MODELS_DIR="/etc/nixos/models"
BASE_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

# Create models directory
sudo mkdir -p "$MODELS_DIR"

# Available models and their sizes (approximate)
declare -A MODELS=(
    ["tiny"]="39MB - Fast, lower accuracy"
    ["base"]="142MB - Good balance of speed and accuracy (recommended)"
    ["small"]="466MB - Better accuracy, slower"
    ["medium"]="1.5GB - High accuracy, much slower"
    ["large-v1"]="2.9GB - Highest accuracy, very slow"
    ["large-v2"]="2.9GB - Latest large model"
    ["large-v3"]="2.9GB - Most recent large model"
    ["large-v3-turbo"]="1.6GB - Near large-v3 quality, medium size"
)

echo "Available Whisper models:"
echo "========================"
for model in "${!MODELS[@]}"; do
    echo "- $model: ${MODELS[$model]}"
done
echo ""

# Default to base model if no argument provided
MODEL=${1:-base}

if [[ ! "${!MODELS[*]}" =~ $MODEL ]]; then
    echo "Error: Invalid model '$MODEL'"
    echo "Available models: ${!MODELS[*]}"
    exit 1
fi

MODEL_FILE="ggml-${MODEL}.bin"
MODEL_PATH="$MODELS_DIR/$MODEL_FILE"

if [[ -f "$MODEL_PATH" ]]; then
    echo "Model $MODEL already exists at $MODEL_PATH"
    echo "File size: $(du -h "$MODEL_PATH" | cut -f1)"
    read -p "Re-download? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

echo "Downloading Whisper model: $MODEL"
echo "Size: ${MODELS[$MODEL]}"
echo "URL: $BASE_URL/$MODEL_FILE"
echo ""

# Download with progress bar
sudo curl -L --progress-bar "$BASE_URL/$MODEL_FILE" -o "$MODEL_PATH"

# Verify download
if [[ -f "$MODEL_PATH" ]]; then
    echo ""
    echo "✓ Model downloaded successfully!"
    echo "Location: $MODEL_PATH"
    echo "Size: $(du -h "$MODEL_PATH" | cut -f1)"

    # Set appropriate permissions
    sudo chmod 644 "$MODEL_PATH"

    echo ""
    echo "You can now use speech-to-text with the $MODEL model."
    echo "To use this model, restart the service: sudo systemctl restart whisper-server"
else
    echo "✗ Download failed!"
    exit 1
fi