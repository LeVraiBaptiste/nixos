#!/usr/bin/env bash
# pre-commit hook: refuse a commit whose staged changes contain a personal value
# from private/vars.yaml (domain, public IP, emails, ...). Enable with:
#   git config core.hooksPath .githooks
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if ! values=$(sops decrypt --output-type json private/vars.yaml 2>/dev/null); then
  echo "check-private-leaks: cannot decrypt private/vars.yaml, skipping" >&2
  exit 0
fi

# Every string value, CIDR suffix dropped. git.personal.name is the GitHub owner,
# which the flake inputs legitimately reference.
patterns=$(mktemp)
trap 'rm -f "$patterns"' EXIT
jq -r 'del(.placeholder, .git.personal.name) | .. | strings | split("/")[0] | select(length >= 6)' \
  <<<"$values" | sort -u > "$patterns"

# Added lines only, outside the encrypted file itself
added=$(git diff --cached -U0 --no-color -- . ':!private/vars.yaml' | grep '^+' | grep -v '^+++' || true)

if hits=$(grep -nF -f "$patterns" <<<"$added"); then
  echo "check-private-leaks: staged changes contain values from private/vars.yaml:" >&2
  # Show the offending lines with the values masked
  while read -r value; do
    hits=${hits//"$value"/<private>}
  done < "$patterns"
  echo "$hits" >&2
  echo "Move them to private/vars.yaml (sops) and read them through vars." >&2
  exit 1
fi
