#!/usr/bin/env bash
# Short checks (2026-11-07), 120 s each, fixed seed 1, unframed seeds (../m1/seeds, read-only):
#   red1 / red0 : fuzz_fprime with -reduce_inputs=1 vs 0. Tests whether file count < new units is the reduce step.
#   spd_vp0 / spd_vp1 : fuzz_spd with -use_value_profile=0 vs 1. Tests whether SPD coverage plateau is a guidance limit.
set -u
cd "$(dirname "$0")" || exit 1
M2="$PWD"
export ASAN_OPTIONS=detect_leaks=0
mkdir -p out/checks
for n in red1 red0 spd_vp0 spd_vp1; do
  mkdir -p "out/checks/$n/corpus" "out/checks/$n/crash"
done
GCOV_PREFIX="$M2/out/checks/red1/gcov" ./out/fprime/fuzz_fprime -reduce_inputs=1 -seed=1 -max_total_time=120 \
  -artifact_prefix=out/checks/red1/crash/ -print_final_stats=1 out/checks/red1/corpus ../m1/seeds > out/checks/red1/run.log 2>&1 &
GCOV_PREFIX="$M2/out/checks/red0/gcov" ./out/fprime/fuzz_fprime -reduce_inputs=0 -seed=1 -max_total_time=120 \
  -artifact_prefix=out/checks/red0/crash/ -print_final_stats=1 out/checks/red0/corpus ../m1/seeds > out/checks/red0/run.log 2>&1 &
GCOV_PREFIX="$M2/out/checks/spd_vp0/gcov" ./out/spd/fuzz_spd -use_value_profile=0 -seed=1 -max_total_time=120 \
  -artifact_prefix=out/checks/spd_vp0/crash/ -print_final_stats=1 out/checks/spd_vp0/corpus ../m1/seeds > out/checks/spd_vp0/run.log 2>&1 &
GCOV_PREFIX="$M2/out/checks/spd_vp1/gcov" ./out/spd/fuzz_spd -use_value_profile=1 -seed=1 -max_total_time=120 \
  -artifact_prefix=out/checks/spd_vp1/crash/ -print_final_stats=1 out/checks/spd_vp1/corpus ../m1/seeds > out/checks/spd_vp1/run.log 2>&1 &
wait
echo "checks finished"
for n in red1 red0 spd_vp0 spd_vp1; do
  files=$(ls "out/checks/$n/corpus" | wc -l)
  new=$(grep -o 'new_units_added: *[0-9]*' "out/checks/$n/run.log")
  execs=$(grep -o 'Done [0-9]* runs' "out/checks/$n/run.log")
  cov=$(grep -o 'cov: [0-9]*' "out/checks/$n/run.log" | tail -1)
  crashes=$(ls "out/checks/$n/crash" | wc -l)
  echo "$n | $execs | $cov | $new | files=$files | crashes=$crashes"
done
