#!/usr/bin/env bash
# One 1 h CMP-on run, seed 7, ASLR off (setarch -R), run alone.
# Compares with cmp1_s7 from the parallel batch in repeat_cmp1_1h.sh (2026-11-09).
set -u
cd "$(dirname "$0")" || exit 1
M2="$PWD"
BIN="$M2/out/fprime/fuzz_fprime"
export ASAN_OPTIONS=detect_leaks=0
D="$M2/out/repeat1h/aslr_s7"
mkdir -p "$D/corpus" "$D/crash"
GCOV_PREFIX="$D/gcov" setarch "$(uname -m)" -R "$BIN" -use_cmp=1 -seed=7 -max_total_time=3600 \
  -artifact_prefix="$D/crash/" -print_final_stats=1 "$D/corpus" ../m1/seeds > "$D/run.log" 2>&1
echo "exit=$?" > "$D/exit.txt"
echo "finished"
