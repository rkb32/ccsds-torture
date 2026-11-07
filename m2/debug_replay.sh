#!/usr/bin/env bash
# Debug: is the DATAOUT_HIT probe compiled in, and what does one framed seed print?
cd "$(dirname "$0")" || exit 1
export ASAN_OPTIONS=detect_leaks=0
echo "probe strings in binary: $(grep -a -c DATAOUT_HIT out/fprime/fuzz_fprime)"
f=$(ls seeds_framed_ro | head -1)
echo "file=$f"
od -An -tx1 "seeds_framed_ro/$f" | head -3
CT_REPLAY=1 ./out/fprime/fuzz_fprime "seeds_framed_ro/$f" > out/fprime/debug_one.log 2>&1
echo "rc=$?"
grep -v profiling out/fprime/debug_one.log | tail -15
echo "gcda warnings: $(grep -c profiling out/fprime/debug_one.log)"
