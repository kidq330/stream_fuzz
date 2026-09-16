#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/_scratch/toml_elixir"
LOG_DIR="$ROOT/_scratch/overnight"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$LOG_DIR/toml_elixir_$STAMP.log"
PIDFILE="$LOG_DIR/toml_elixir.pid"
DURATION="${DURATION:-2h}"
MAX_FAILURES="${MAX_FAILURES:-20}"
PROGRESS_EVERY="${PROGRESS_EVERY:-2m}"

export MIX_HOME="${MIX_HOME:-$ROOT/.mix}"
export HEX_HOME="${HEX_HOME:-$ROOT/.hex}"
export MIX_ENV=test

mkdir -p "$LOG_DIR"
cd "$PROJECT"
exec > >(tee "$LOG") 2>&1

echo "=== StreamFuzz bug-hunt: toml_elixir ==="
echo "started:  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "duration: $DURATION"
echo "pid:      $$"
echo $$ > "$PIDFILE"
ln -sfn "$(basename "$LOG")" "$LOG_DIR/toml_elixir_latest.log"

mix deps.get
mix compile

set +e
mix stream_fuzz test/toml_property_test.exs \
  --duration "$DURATION" \
  --cover-app toml_elixir \
  --max-failures "$MAX_FAILURES" \
  --progress-every "$PROGRESS_EVERY" \
  --corpus "_build/stream_fuzz/corpus"
status=$?
set -e

echo "finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "exit:     $status"
rm -f "$PIDFILE"
exit "$status"
