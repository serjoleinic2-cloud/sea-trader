#!/usr/bin/env bash
set -euo pipefail
# No live save files are touched. The temporary directory is retained for diagnosis.
test_data_dir="$(mktemp -d -t sea-trader-tests.XXXXXX)"
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
engine="${GODOT_BIN:-godot}"
export XDG_DATA_HOME="$test_data_dir"
export SEA_TRADER_ISOLATED_TESTS=1
echo "Isolated test data: $test_data_dir"
"$engine" --headless --path "$project_dir" --editor --import --quit
"$engine" --headless --path "$project_dir" res://tests/test_runner.tscn
