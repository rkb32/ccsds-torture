#!/usr/bin/env bash
# Follow-up FPD runs suggested by the Opus review (2026-11-07):
#   fprime_framed : 1h, F'-framed seeds (seeds_framed_ro), separate writable corpus
#   fprime_none   : 1h, unframed CCSDS seeds (../m1/seeds), separate writable corpus
#   fprime_cmp0/1 : 15 min each, unframed seeds, comparison feedback off vs on
# Seed dirs are read-only inputs; libFuzzer writes new units only to the first (writable) dir.
set -u
cd "$(dirname "$0")" || exit 1
BIN="$PWD/out/fprime/fuzz_fprime"
export ASAN_OPTIONS=detect_leaks=0

run() {
  local name=$1 secs=$2 flags=$3
  shift 3
  mkdir -p "out/$name/corpus" "out/$name/crash"
  # Per-run gcov prefix so concurrent runs do not corrupt each other's .gcda profile files.
  GCOV_PREFIX="$PWD/out/$name/gcov" "$BIN" $flags -max_total_time="$secs" \
    -artifact_prefix="out/$name/crash/" -print_final_stats=1 \
    "out/$name/corpus" "$@" > "out/$name/run.log" 2>&1 &
  echo "$name pid $!"
}

run fprime_framed 3600 "" seeds_framed_ro
run fprime_none 3600 "" ../m1/seeds
run fprime_cmp0 900 "-use_cmp=0" ../m1/seeds
run fprime_cmp1 900 "-use_cmp=1" ../m1/seeds
wait
echo "all runs finished"
