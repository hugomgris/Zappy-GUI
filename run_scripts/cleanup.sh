#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== cleaning Server ==="
make fclean -C "$ROOT_DIR/server"

echo "=== cleaning Client ==="
make fclean -C "$ROOT_DIR/client"

echo "=== cleaning Logs ==="
mkdir -p "$ROOT_DIR/logs"
find "$ROOT_DIR/logs" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

echo "=== CLEAN ==="
