#!/usr/bin/env bash
# Bump overlays/orca-ide.nix to the latest upstream release (fish alias `update`
# and .github/workflows/update.yml).
# Not nix-update: with Nix >= 2.35 (lazy trees) it passes a flake store path that
# is never materialized, and its eval fails with
# "opening file /nix/store/...-source: No such file or directory".
set -euo pipefail

cd "$(dirname "$0")/.."
f=overlays/orca-ide.nix

old=$(nix eval --raw .#orca-ide.version)
new=$(curl -fsSL ${GH_TOKEN:+-H "Authorization: Bearer $GH_TOKEN"} \
  https://api.github.com/repos/stablyai/orca/releases/latest | jq -r .tag_name | sed 's/^v//')

if [ "$new" != "$old" ]; then
  url="https://github.com/stablyai/orca/releases/download/v$new/orca-linux.AppImage"
  hash=$(nix store prefetch-file --json "$url" | jq -r .hash)
  sed -i -e "s|version = \"$old\";|version = \"$new\";|" \
    -e "s|hash = \"sha256-[^\"]*\";|hash = \"$hash\";|" "$f"
  # Fail if the sed did not land
  test "$(nix eval --raw .#orca-ide.version)" = "$new"
  test "$(nix eval --raw .#orca-ide.src.outputHash)" = "$hash"
  echo "orca-ide: $old -> $new"
else
  echo "orca-ide: $old is up to date"
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "old=$old" >>"$GITHUB_OUTPUT"
  echo "new=$new" >>"$GITHUB_OUTPUT"
fi
