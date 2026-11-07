#!/usr/bin/env bash
# Replays each file in a directory through fuzz_fprime (CT_REPLAY=1) and records the count of DATAOUT_HIT lines.
# Usage: replay_fprime.sh <seed_dir> <out_txt>
# Output lines: "<hit 0|1> <file name>". A hit means the input reached dataOut (FprimeDeframer.cpp:110).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$HERE/out/fprime/fuzz_fprime"
export ASAN_OPTIONS=detect_leaks=0
: > "$2"
for f in "$1"/*; do
  [ -f "$f" ] || continue
  hit=$(CT_REPLAY=1 "$BIN" "$f" 2>&1 | grep -c DATAOUT_HIT)
  echo "$hit $(basename "$f")" >> "$2"
done
echo "done $(wc -l < "$2") files"
