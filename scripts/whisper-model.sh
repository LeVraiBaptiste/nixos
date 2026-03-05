#!/usr/bin/env bash

# Manage which model whisper-server uses.
#
# Usage:
#   whisper-model              Show current model
#   whisper-model list         List available models
#   whisper-model switch NAME  Switch to a different model and restart server

MODELS_DIR="/etc/nixos/models"
STATE_DIR="/var/lib/whisper-server"
SYMLINK="$STATE_DIR/model.bin"

current_model() {
    if [ -L "$SYMLINK" ]; then
        target=$(readlink -f "$SYMLINK")
        basename "$target" .bin | sed 's/^ggml-//'
    elif [ -e "$SYMLINK" ]; then
        echo "(not a symlink: $SYMLINK)"
    else
        echo "(none)"
    fi
}

list_models() {
    local current
    current=$(current_model)

    echo "Available models in $MODELS_DIR:"
    local found=0
    for f in "$MODELS_DIR"/ggml-*.bin; do
        [ -f "$f" ] || continue
        found=1
        name=$(basename "$f" .bin | sed 's/^ggml-//')
        size=$(du -h "$f" | cut -f1)
        if [ "$name" = "$current" ]; then
            echo "  * $name ($size) [active]"
        else
            echo "    $name ($size)"
        fi
    done

    if [ "$found" -eq 0 ]; then
        echo "  (none — run 'setup-whisper-models' to download one)"
    fi
}

switch_model() {
    local name="$1"
    local model_file="$MODELS_DIR/ggml-${name}.bin"

    if [ ! -f "$model_file" ]; then
        echo "Error: model '$name' not found at $model_file" >&2
        echo "Run 'setup-whisper-models $name' to download it, or 'whisper-model list' to see available models." >&2
        return 1
    fi

    local current
    current=$(current_model)
    if [ "$name" = "$current" ]; then
        echo "Already using '$name'."
        return 0
    fi

    echo "Switching from '$current' to '$name'..."
    sudo ln -sf "$model_file" "$SYMLINK"
    sudo systemctl restart whisper-server
    echo "Done. Server restarting with model '$name'."
    echo "Use 'systemctl status whisper-server' to check progress."
}

case "${1:-}" in
    "")
        echo "Current model: $(current_model)"
        ;;
    list)
        list_models
        ;;
    switch)
        if [ -z "${2:-}" ]; then
            echo "Usage: whisper-model switch <model-name>" >&2
            echo "Run 'whisper-model list' to see available models." >&2
            exit 1
        fi
        switch_model "$2"
        ;;
    *)
        echo "Usage: whisper-model [list | switch <name>]" >&2
        exit 1
        ;;
esac
