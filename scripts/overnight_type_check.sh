#!/usr/bin/env bash
# Overnight StreamFuzz campaign against Qqwy/elixir-type_check.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/_scratch/type_check"
LOG_DIR="$ROOT/_scratch/overnight"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$LOG_DIR/type_check_$STAMP.log"
PIDFILE="$LOG_DIR/type_check.pid"

DURATION="${DURATION:-8h}"
MAX_FAILURES="${MAX_FAILURES:-50}"
PROGRESS_EVERY="${PROGRESS_EVERY:-5m}"

export MIX_HOME="${MIX_HOME:-$ROOT/.mix}"
export HEX_HOME="${HEX_HOME:-$ROOT/.hex}"
export MIX_ENV=test

mkdir -p "$LOG_DIR"
cd "$PROJECT"

exec > >(tee "$LOG") 2>&1

echo "=== StreamFuzz overnight: type_check ==="
echo "started:  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "duration: $DURATION"
echo "cwd:      $PROJECT"
echo "log:      $LOG"
echo "pid:      $$"
echo
echo $$ > "$PIDFILE"
ln -sfn "$(basename "$LOG")" "$LOG_DIR/type_check_latest.log"

mix deps.get
mix compile

set +e
mix stream_fuzz \
  --duration "$DURATION" \
  --cover-app type_check \
  --max-failures "$MAX_FAILURES" \
  --progress-every "$PROGRESS_EVERY" \
  --corpus "_build/stream_fuzz/corpus"
status=$?
set -e

echo
echo "finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "exit:     $status"
echo "corpus:   $PROJECT/_build/stream_fuzz/corpus"
echo "failures: $PROJECT/_build/stream_fuzz/failures"
rm -f "$PIDFILE"
exit "$status"
