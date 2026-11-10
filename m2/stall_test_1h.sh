#!/usr/bin/env bash
# 1 h rerun of CMP-on seeds 7 and 8 (slow units in the 2026-11-09 batch) plus control seed 4.
# Same fuzz flags as repeat_cmp1_1h.sh. Adds a wall-clock stamp to every log line and a 1 Hz
# heartbeat, so a gap in the heartbeat (VM/host stall) can be compared with each slow unit.
set -u
cd "$(dirname "$0")" || exit 1
M2="$PWD"
BIN="$M2/out/fprime/fuzz_fprime"
export ASAN_OPTIONS=detect_leaks=0
OUT="$M2/out/stall1h"
mkdir -p "$OUT"

( while true; do date '+%F %T'; sleep 1; done ) > "$OUT/heartbeat.log" 2>&1 &
HB=$!

pids=()
for s in 7 8 4; do
  name="cmp1_s$s"
  d="$OUT/$name"
  mkdir -p "$d/corpus" "$d/crash"
  (
    GCOV_PREFIX="$M2/out/stall1h/$name/gcov" "$BIN" -use_cmp=1 -seed="$s" -max_total_time=3600 \
      -artifact_prefix="$d/crash/" -print_final_stats=1 \
      "$d/corpus" ../m1/seeds 2>&1 \
    | while IFS= read -r l; do printf '%s %s\n' "$(date '+%F %T')" "$l"; done > "$d/run.log"
  ) &
  pids+=($!)
done

wait "${pids[@]}"
kill "$HB" 2>/dev/null
echo "all runs finished $(date '+%F %T')"
