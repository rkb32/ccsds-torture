#!/usr/bin/env bash
# Repeat trials (2026-11-07): comparison feedback off vs on, 3 seeds per arm, 900 s each.
# Unframed CCSDS seeds (../m1/seeds, read-only). Fresh writable corpus and crash dir per trial.
# Runs all 6 trials in parallel (14 cores, ~550 MB RSS each), then replays each corpus.
set -u
cd "$(dirname "$0")" || exit 1
M2="$PWD"
BIN="$M2/out/fprime/fuzz_fprime"
export ASAN_OPTIONS=detect_leaks=0
mkdir -p out/trials

for arm in cmp0 cmp1; do
  flag="-use_cmp=${arm#cmp}"
  for s in 1 2 3; do
    name="${arm}_s${s}"
    mkdir -p "out/trials/$name/corpus" "out/trials/$name/crash"
    GCOV_PREFIX="$M2/out/trials/$name/gcov" "$BIN" "$flag" -seed="$s" -max_total_time=900 \
      -artifact_prefix="out/trials/$name/crash/" -print_final_stats=1 \
      "out/trials/$name/corpus" ../m1/seeds > "out/trials/$name/run.log" 2>&1 &
    echo "$name pid $!"
  done
done
wait
echo "all trials finished"

for arm in cmp0 cmp1; do
  for s in 1 2 3; do
    name="${arm}_s${s}"
    bash "$M2/replay_fprime.sh" "$M2/out/trials/$name/corpus" "$M2/out/trials/replay_$name.txt" > /dev/null 2>&1
    files=$(wc -l < "out/trials/replay_$name.txt")
    hits=$(grep -c '^[1-9]' "out/trials/replay_$name.txt")
    dbf=$(for f in out/trials/$name/corpus/*; do [ -f "$f" ] && head -c4 "$f" | od -An -tx1 | tr -d ' \n' | grep -q '^deadbeef' && echo x; done | wc -l)
    new=$(grep -o 'new_units_added: *[0-9]*' "out/trials/$name/run.log")
    execs=$(grep -o 'Done [0-9]* runs' "out/trials/$name/run.log")
    cov=$(grep -o 'cov: [0-9]*' "out/trials/$name/run.log" | tail -1)
    crashes=$(ls "out/trials/$name/crash" | wc -l)
    echo "$name | $execs | $cov | $new | files=$files | start_DEADBEEF=$dbf | dataOut_hit_files=$hits | crashes=$crashes"
  done
done
