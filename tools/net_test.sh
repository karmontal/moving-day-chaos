#!/usr/bin/env bash
# Online smoke test: a host and a client process play a short job over 127.0.0.1.
# Usage: tools/net_test.sh [path/to/godot] [lan|nat|relay]   (nat/relay need noray on 127.0.0.1)
set -u
GODOT=${1:-godot}
MODE=${2:-lan}
cd "$(dirname "$0")/.."
rm -f /tmp/mdc_net_room_code.txt  # never let the client read a stale room code
"$GODOT" --headless --path . res://tools/net_test.tscn -- host "$MODE" > /tmp/mdc_net_host.log 2>&1 &
HOST=$!
"$GODOT" --headless --path . res://tools/net_test.tscn -- client "$MODE" > /tmp/mdc_net_client.log 2>&1
CODE=$?
wait $HOST
HOST_CODE=$?
grep -E "^(host|client):|^  " /tmp/mdc_net_host.log /tmp/mdc_net_client.log
grep -E "SCRIPT ERROR" -A2 /tmp/mdc_net_host.log /tmp/mdc_net_client.log | head -20
[ $CODE -eq 0 ] && [ $HOST_CODE -eq 0 ]
