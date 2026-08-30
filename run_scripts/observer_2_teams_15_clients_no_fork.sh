#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

export ZAPPY_EASY_ASCENSION=0

# Cleanup function to kill the server when the script exits
cleanup() {
    echo "Cleaning up..."
    pkill -f "./zappy -p 8674" || true
}
trap cleanup EXIT

echo "=== Building Server ==="
make -C "$ROOT_DIR/server"

echo "=== Starting Server ==="
pkill -f "./zappy -p" || true
sleep 1
# Run the server from its own directory so it finds its assets/certs
(cd "$ROOT_DIR/server" && ./zappy -p 8674 -x 15 -y 15 -n team1 team2 -c 30 -f 10 -t 1 > "$ROOT_DIR/logs/[SERVER]---[teams=2][clients=15][fork=NO].txt" 2>&1 &)
sleep 1 # Wait a moment for the server to fully start and bind the port

echo "=== Building Client ==="
for i in {1..15}; do
    "$ROOT_DIR/client/client" localhost 8674 team1 --no-fork 2> "$ROOT_DIR/logs/[CLIENT-team1-${i}]---[teams=2][clients=15][fork=NO].txt" &
    sleep 0.5
done

for i in {1..14}; do
    "$ROOT_DIR/client/client" localhost 8674 team2 --no-fork 2> "$ROOT_DIR/logs/[CLIENT-team2-${i}]---[teams=2][clients=15][fork=NO].txt" &
    sleep 0.5
done
"$ROOT_DIR/client/client" localhost 8674 team2 --no-fork 2> "$ROOT_DIR/logs/[CLIENT-team2-15]---[teams=2][clients=15][fork=NO].txt" &
wait
