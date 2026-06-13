#!/usr/bin/env bash
set -euo pipefail

FLAKE="/etc/nixos"
HOSTNAME=$(hostname)
TARGET="${1:-$HOSTNAME}"

if [ "$TARGET" = "$HOSTNAME" ]; then
  sudo nixos-rebuild switch --flake "$FLAKE#$TARGET"
else
  nixos-rebuild switch --flake "$FLAKE#$TARGET" \
    --target-host "$TARGET" \
    --elevate=sudo
fi
