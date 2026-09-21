#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
simulation_data="$(mktemp -d -t sea-economy.XXXXXX)"
export XDG_DATA_HOME="$simulation_data"
export SEA_TRADER_ISOLATED_TESTS=1
engine="${GODOT_BIN:-godot}"
"$engine" --headless --path "$project_dir" --editor --import --quit
"$engine" --headless --path "$project_dir" res://tests/economy/economy_simulator.tscn 2>&1 | tee "$simulation_data/output.log"
if grep -qE 'SCRIPT ERROR|Parse Error' "$simulation_data/output.log"; then
  exit 1
fi
echo "Results: $project_dir/tests/economy/results.json"
