#!/usr/bin/env bash
# Replays the three seed sets through fuzz_fprime and prints hit counts (inputs that reach dataOut).
set -u
cd "$(dirname "$0")" || exit 1
bash replay_fprime.sh seeds_spd out/fprime/replay_seeds_spd.txt
python3 make_framed_seeds.py ../m1/seeds seeds_framed_ro
bash replay_fprime.sh seeds_framed_ro out/fprime/replay_framed.txt
bash replay_fprime.sh ../m1/seeds out/fprime/replay_none.txt
for f in out/fprime/replay_seeds_spd.txt out/fprime/replay_framed.txt out/fprime/replay_none.txt; do
  echo "$f hits=$(grep -c '^1 ' "$f") of=$(grep -c '' "$f")"
done
echo "first seeds_spd hits:"
grep '^1 ' out/fprime/replay_seeds_spd.txt | head -20
