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
pkill -f zappy || true
sleep 1
# Run the server from its own directory so it finds its assets/certs
(cd "$ROOT_DIR/server" && ./zappy -p 8674 -x 10 -y 10 -n team1 -c 10 -f 10 > "$ROOT_DIR/logs/server_log_normal_probe_three_clients.txt" 2>&1 &)
sleep 1 # Wait a moment for the server to fully start and bind the port

echo "=== Running server/run.sh ==="
(cd "$ROOT_DIR/server" && ./run.sh)

echo "=== Building Client ==="
make -C "$ROOT_DIR/client"

echo "=== Running Clients ==="
for i in {1..2}; do
    "$ROOT_DIR/client/client" localhost 8674 team1 2> "$ROOT_DIR/logs/client_log_normal_probe_three_clients_${i}.txt" &
    sleep 0.5
done
"$ROOT_DIR/client/client" localhost 8674 team1 2> "$ROOT_DIR/logs/client_log_normal_probe_three_clients_3.txt"