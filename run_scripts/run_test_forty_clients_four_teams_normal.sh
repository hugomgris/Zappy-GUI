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
(cd "$ROOT_DIR/server" && ./zappy -p 8674 -x 30 -y 30 -n team1 team2 team3 team4 -c 60 -f 10 > "$ROOT_DIR/logs/server_log_normal_probe_four_teams.txt" 2>&1 &)
sleep 1 # Wait a moment for the server to fully start and bind the port

echo "=== Running server/run.sh ==="
(cd "$ROOT_DIR/server" && ./run.sh)

echo "=== Building Client ==="
make -C "$ROOT_DIR/client"

echo "=== Running Clients ==="
for i in {1..10}; do
    "$ROOT_DIR/client/client" localhost 8674 team1 2> "$ROOT_DIR/logs/client_log_normal_four_teams_team1_${i}.txt" &
    sleep 0.5
done

for i in {1..10}; do
    "$ROOT_DIR/client/client" localhost 8674 team2 2> "$ROOT_DIR/logs/client_log_normal_four_teams_team2_${i}.txt" &
    sleep 0.5
done

for i in {1..10}; do
    "$ROOT_DIR/client/client" localhost 8674 team3 2> "$ROOT_DIR/logs/client_log_normal_four_teams_team3_${i}.txt" &
    sleep 0.5
done

for i in {1..10}; do
    "$ROOT_DIR/client/client" localhost 8674 team4 2> "$ROOT_DIR/logs/client_log_normal_four_teams_team4_${i}.txt" &
    sleep 0.5
done

echo "=== Clients launched ==="
wait
