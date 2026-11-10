#!/usr/bin/env bash
# Repeat 1h CMP-on trials with fresh seeds (seeds 4-9), to test valid-frame reproducibility (2026-11-09).
# Unframed seeds (../m1/seeds, read-only). Fresh writable corpus and crash dir per trial.
# Runs all 6 trials in parallel, then replays each corpus to count dataOut hits.
set -u
cd "$(dirname "$0")" || exit 1
M2="$PWD"
BIN="$M2/out/fprime/fuzz_fprime"
export ASAN_OPTIONS=detect_leaks=0
mkdir -p out/repeat1h

for s in 4 5 6 7 8 9; do
  name="cmp1_s${s}"
  mkdir -p "out/repeat1h/$name/corpus" "out/repeat1h/$name/crash"
  GCOV_PREFIX="$M2/out/repeat1h/$name/gcov" "$BIN" -use_cmp=1 -seed="$s" -max_total_time=3600 \
    -artifact_prefix="out/repeat1h/$name/crash/" -print_final_stats=1 \
    "out/repeat1h/$name/corpus" ../m1/seeds > "out/repeat1h/$name/run.log" 2>&1 &
  echo "$name pid $!"
done
wait
echo "all trials finished"

for s in 4 5 6 7 8 9; do
  name="cmp1_s${s}"
  bash "$M2/replay_fprime.sh" "$M2/out/repeat1h/$name/corpus" "$M2/out/repeat1h/replay_$name.txt" > /dev/null 2>&1
  files=$(wc -l < "$M2/out/repeat1h/replay_$name.txt")
  hits=$(grep -c '^[1-9]' "$M2/out/repeat1h/replay_$name.txt")
  execs=$(grep -o 'Done [0-9]* runs' "out/repeat1h/$name/run.log")
  budget=$(bash "$M2/checkbudget.sh" 3600 "out/repeat1h/$name/run.log")
  crashes=$(ls "out/repeat1h/$name/crash" | grep -cE '^(crash|oom|timeout|leak)-')
  slow=$(ls "out/repeat1h/$name/crash" | grep -c '^slow-unit-')
  echo "$name | $execs | files=$files | dataOut_hit_files=$hits | crashes=$crashes | slow_units=$slow | $budget"
done
