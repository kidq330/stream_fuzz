#!/usr/bin/env bash
# StreamFuzz bug-hunt against narrowtux/abacus (properties added in-tree).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/_scratch/abacus"
LOG_DIR="$ROOT/_scratch/overnight"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$LOG_DIR/abacus_$STAMP.log"
PIDFILE="$LOG_DIR/abacus.pid"

DURATION="${DURATION:-2h}"
MAX_FAILURES="${MAX_FAILURES:-20}"
PROGRESS_EVERY="${PROGRESS_EVERY:-2m}"

export MIX_HOME="${MIX_HOME:-$ROOT/.mix}"
export HEX_HOME="${HEX_HOME:-$ROOT/.hex}"
export MIX_ENV=test
# Cut deprecation noise that blew up the type_check log.
export ELIXIR_ERL_OPTIONS="${ELIXIR_ERL_OPTIONS:-} +sbwt none"

mkdir -p "$LOG_DIR"
cd "$PROJECT"

exec > >(tee "$LOG") 2>&1

echo "=== StreamFuzz bug-hunt: abacus ==="
echo "started:  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "duration: $DURATION"
echo "cwd:      $PROJECT"
echo "log:      $LOG"
echo "pid:      $$"
echo
echo $$ > "$PIDFILE"
ln -sfn "$(basename "$LOG")" "$LOG_DIR/abacus_latest.log"

mix deps.get
mix compile

set +e
mix stream_fuzz test/abacus_property_test.exs \
  --duration "$DURATION" \
  --cover-app abacus \
  --max-failures "$MAX_FAILURES" \
  --progress-every "$PROGRESS_EVERY" \
  --corpus "_build/stream_fuzz/corpus"
status=$?
set -e

echo
echo "finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "exit:     $status"
echo "failures: $PROJECT/_build/stream_fuzz/failures"
rm -f "$PIDFILE"
exit "$status"
