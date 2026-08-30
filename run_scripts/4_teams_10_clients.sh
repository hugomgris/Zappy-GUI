#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

export ZAPPY_EASY_ASCENSION=0
export ZAPPY_ROOT_DIR="$ROOT_DIR"

# Cleanup function to kill the server when the script exits
cleanup() {
    echo "Cleaning up..."
    pkill -f "./zappy -p 8674" || true
}
trap cleanup EXIT

echo "=== Building Server ==="
make -C "$ROOT_DIR/server"

echo "=== Starting Server ==="
pkill -f zappy || true
sleep 1
# Run the server from its own directory so it finds its assets/certs
(cd "$ROOT_DIR/server" && ./zappy -p 8674 -x 30 -y 30 -n team1 team2 team3 team4 -c 80 -f 10 > "$ROOT_DIR/logs/[SERVER]---[teams=4][clients=10][fork=YES].txt" 2>&1 &)
sleep 1 # Wait a moment for the server to fully start and bind the port

echo "=== Building Clients ==="
make -C "$ROOT_DIR/client"

echo "=== Running Clients ==="
for i in {1..10}; do
    "$ROOT_DIR/client/client" localhost 8674 team1 2> "$ROOT_DIR/logs/[CLIENT-team-1-${i}]---[teams=4][clients=10][fork=YES].txt" &
    sleep 0.5
done

for i in {1..10}; do
    "$ROOT_DIR/client/client" localhost 8674 team2 2> "$ROOT_DIR/logs/[CLIENT-team-2-${i}]---[teams=4][clients=10][fork=YES].txt" &
    sleep 0.5
done

for i in {1..10}; do
    "$ROOT_DIR/client/client" localhost 8674 team3 2> "$ROOT_DIR/logs/[CLIENT-team-3-${i}]---[teams=4][clients=10][fork=YES].txt" &
    sleep 0.5
done

for i in {1..10}; do
    "$ROOT_DIR/client/client" localhost 8674 team4 2> "$ROOT_DIR/logs/[CLIENT-team-4-${i}]---[teams=4][clients=10][fork=YES].txt" &
    sleep 0.5
done
"$ROOT_DIR/client/client" localhost 8674 team4 2> "$ROOT_DIR/logs/[CLIENT-team-4-10]---[teams=4][clients=10][fork=YES].txt" &
sleep 0.5

echo "=== Clients launched ==="

echo "=== Running server/run.sh ==="
(cd "$ROOT_DIR/server" && ./run.sh)

wait
