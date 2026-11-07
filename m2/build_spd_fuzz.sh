#!/usr/bin/env bash
# Builds the M2 libFuzzer target for F' SpacePacketDeframer.
# Reuses the compile and link commands ninja already knows for the clang build cache (build-fuzz),
# swaps the unit-test main for the libFuzzer harness, and links with -fsanitize=fuzzer.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BLD="$HERE/fprime/build-fuzz"
OBJ="F-Prime/Svc/Ccsds/SpacePacketDeframer/CMakeFiles/Svc_Ccsds_SpacePacketDeframer_ut_exe.dir/test/ut/SpacePacketDeframerTester.cpp.o"
OUT="$HERE/out/spd"
mkdir -p "$OUT"
export PATH="$HOME/ct-venv/bin:/usr/bin:/bin"

cd "$BLD"

# 1. Compile the harness with the tester's own flags (includes, defines, std).
CC_CMD=$(ninja -t commands "$OBJ" | tail -n 1)
FLAGS=$(echo "$CC_CMD" | sed -E 's/ -o [^ ]+//; s/ -c [^ ]+//; s/-fsanitize=fuzzer-no-link/-fsanitize=fuzzer/')
# shellcheck disable=SC2086
$FLAGS -c "$HERE/harness/fuzz_spd.cpp" -o "$OUT/fuzz_spd_harness.o"

# 2. Link: ninja's unit-test link line, minus the gtest main and the unit-test main, plus the harness.
LINK_CMD=$(ninja -t commands bin/Linux/Svc_Ccsds_SpacePacketDeframer_ut_exe | tail -n 1)
LINK=$(echo "$LINK_CMD" \
    | sed -E 's/^: && //' \
    | sed -E 's/ && :$//' \
    | sed -E "s# -o [^ ]+# -o $OUT/fuzz_spd#" \
    | sed -E "s#[^ ]*SpacePacketDeframerTestMain\.cpp\.o##" \
    | sed -E "s#[^ ]*libgtest_main\.a##" \
    | sed -E "s#-fsanitize=fuzzer-no-link#-fsanitize=fuzzer#")
case "$LINK" in
    *"-o $OUT/fuzz_spd"*) ;;
    *) echo "link command rewrite failed" >&2; exit 1 ;;
esac
eval "$LINK \"$OUT/fuzz_spd_harness.o\" -fsanitize=fuzzer"
test -x "$OUT/fuzz_spd" || { echo "link produced no binary" >&2; exit 1; }

echo "built $OUT/fuzz_spd"
