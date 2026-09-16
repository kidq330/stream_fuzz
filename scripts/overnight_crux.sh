#!/usr/bin/env bash
# Overnight StreamFuzz campaign against ash-project/crux.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRUX="$ROOT/_scratch/crux"
LOG_DIR="$ROOT/_scratch/overnight"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$LOG_DIR/crux_$STAMP.log"
PIDFILE="$LOG_DIR/crux.pid"

DURATION="${DURATION:-8h}"
MAX_FAILURES="${MAX_FAILURES:-50}"
PROGRESS_EVERY="${PROGRESS_EVERY:-5m}"

export MIX_HOME="${MIX_HOME:-$ROOT/.mix}"
export HEX_HOME="${HEX_HOME:-$ROOT/.hex}"
export MIX_ENV=test

mkdir -p "$LOG_DIR"
cd "$CRUX"

exec > >(tee "$LOG") 2>&1

echo "=== StreamFuzz overnight: crux ==="
echo "started:  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "duration: $DURATION"
echo "cwd:      $CRUX"
echo "log:      $LOG"
echo "pid:      $$"
echo
echo $$ > "$PIDFILE"
ln -sfn "$(basename "$LOG")" "$LOG_DIR/crux_latest.log"

mix deps.get
mix compile

set +e
mix stream_fuzz \
  --duration "$DURATION" \
  --cover-app crux \
  --max-failures "$MAX_FAILURES" \
  --progress-every "$PROGRESS_EVERY" \
  --corpus "_build/stream_fuzz/corpus"
status=$?
set -e

echo
echo "finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "exit:     $status"
echo "corpus:   $CRUX/_build/stream_fuzz/corpus"
echo "failures: $CRUX/_build/stream_fuzz/failures"
rm -f "$PIDFILE"
exit "$status"
