#!/usr/bin/env bash
# Auto-backup Home Assistant config to a private GitHub repo.
# Runs daily via systemd timer. Bootstrap (git init, deploy key, first push) is manual.

set -euo pipefail

export GIT_SSH_COMMAND="ssh -i /root/.ssh/ha-deploy-key -o StrictHostKeyChecking=accept-new"

cd /srv/hass/config

git config user.name "ha-config-backup"
git config user.email "ha-config-backup@homelab"

git add -A

if git diff --cached --quiet; then
  echo "No changes to commit"
  exit 0
fi

git commit -m "auto: $(date +%Y-%m-%d)"
git push
