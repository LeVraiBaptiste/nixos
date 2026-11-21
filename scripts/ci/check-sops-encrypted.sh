#!/usr/bin/env bash
# Fail if a file covered by a .sops.yaml creation rule is committed unencrypted.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

status=0
checked=0
while read -r regex; do
  while read -r file; do
    [ -n "$file" ] || continue
    checked=$((checked + 1))
    if sops filestatus "$file" | grep -q '"encrypted":true'; then
      echo "ok        $file"
    else
      echo "PLAINTEXT $file"
      status=1
    fi
  done < <(git ls-files | grep -E "$regex" || true)
done < <(grep -oP 'path_regex:\s*\K\S+' .sops.yaml)

[ "$checked" -gt 0 ] || { echo "no file matches the .sops.yaml rules"; exit 1; }
exit $status
