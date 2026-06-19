#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
HOSTNAME=$(hostname)

echo "==> Rebuilding $HOSTNAME (local)..."
"$SCRIPT_DIR/rebuild.sh"

echo "==> Rebuilding server..."
"$SCRIPT_DIR/rebuild.sh" server

echo "==> Rebuilding remote..."
"$SCRIPT_DIR/rebuild.sh" remote

echo "==> All hosts rebuilt successfully."
