#!/usr/bin/env bash
set -euo pipefail

FLAKE="/etc/nixos"
HOSTNAME=$(hostname)
TARGET="${1:-$HOSTNAME}"

# Personal values: decrypt private/vars.yaml into a tmpfs dir and swap it in for the
# placeholder `private` input. Never written to the repo or the lock file.
PRIVATE=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/nixos-private.XXXXXX")
trap 'rm -rf "$PRIVATE"' EXIT
sops decrypt --output-type json "$FLAKE/private/vars.yaml" > "$PRIVATE/vars.json"
OVERRIDE=(--override-input private "path:$PRIVATE" --no-write-lock-file)

if [ "$TARGET" = "$HOSTNAME" ]; then
  sudo nixos-rebuild switch --flake "$FLAKE#$TARGET" "${OVERRIDE[@]}"
else
  nixos-rebuild switch --flake "$FLAKE#$TARGET" "${OVERRIDE[@]}" \
    --target-host "$TARGET" \
    --elevate=sudo \
    --ask-elevate-password
fi
