#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Keep test preferences and editor cache separate from normal play.
export XDG_DATA_HOME="$PWD/builds/test-data"
export XDG_CONFIG_HOME="$PWD/builds/test-config"
export XDG_CACHE_HOME="$PWD/builds/test-cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
tools/run.sh --headless --editor --import --quit > builds/test-import.log 2>&1
tools/run.sh --headless --script tests/input_test.gd 2>&1 | tee builds/input-test.log
if ! grep -q 'INPUT TEST: PASS' builds/input-test.log; then exit 1; fi
# In-engine assertions cover bounds and recipe transitions.
timeout 30 tools/run.sh --headless -- --smoke-test 2>&1 | tee builds/smoke-test.log
if ! grep -q 'SMOKE TEST PASS' builds/smoke-test.log; then exit 1; fi
