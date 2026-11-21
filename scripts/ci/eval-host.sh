#!/usr/bin/env bash
# Print the system drvPath of a host, evaluated with the placeholder personal values.
# The guard that refuses placeholders is lifted: this is for CI, never for deploying.
set -euo pipefail

host=$1
repo=$(git rev-parse --show-toplevel)

private=$(mktemp -d)
trap 'rm -rf "$private"' EXIT
jq '.placeholder = false' "$repo/private/example/vars.json" > "$private/vars.json"

nix eval --raw \
  "$repo#nixosConfigurations.$host.config.system.build.toplevel.drvPath" \
  --override-input private "path:$private" \
  --no-write-lock-file
