#!/usr/bin/env bash
# Builds the M2 libFuzzer target for F' FprimeDeframer.
# Builds the unit-test objects in the clang build cache (build-fuzz) first, then reuses ninja's compile and link
# commands, swaps the unit-test main for the libFuzzer harness, and links with -fsanitize=fuzzer.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BLD="$HERE/fprime/build-fuzz"
OBJ="F-Prime/Svc/FprimeDeframer/CMakeFiles/Svc_FprimeDeframer_ut_exe.dir/test/ut/FprimeDeframerTester.cpp.o"
TARGET="bin/Linux/Svc_FprimeDeframer_ut_exe"
OUT="$HERE/out/fprime"
mkdir -p "$OUT"
export PATH="$HOME/ct-venv/bin:/usr/bin:/bin"

cd "$BLD"

# 0. Make sure the unit-test objects exist (instrumented with -fsanitize=fuzzer-no-link).
ninja -j4 "$TARGET" > "$OUT/ninja_objects.log" 2>&1

# 1. Compile the harness with the tester's own flags (includes, defines, std).
CC_CMD=$(ninja -t commands "$OBJ" | tail -n 1)
FLAGS=$(echo "$CC_CMD" | sed -E 's/ -o [^ ]+//; s/ -c [^ ]+//; s/-fsanitize=fuzzer-no-link/-fsanitize=fuzzer/')
# shellcheck disable=SC2086
$FLAGS -c "$HERE/harness/fuzz_fprime.cpp" -o "$OUT/fuzz_fprime_harness.o"

# 2. Link: ninja's unit-test link line, minus the gtest main and the unit-test main, plus the harness.
LINK_CMD=$(ninja -t commands "$TARGET" | tail -n 1)
LINK=$(echo "$LINK_CMD" \
    | sed -E 's/^: && //' \
    | sed -E 's/ && :$//' \
    | sed -E "s# -o [^ ]+# -o $OUT/fuzz_fprime#" \
    | sed -E "s#[^ ]*FprimeDeframerTestMain\.cpp\.o##" \
    | sed -E "s#[^ ]*libgtest_main\.a##" \
    | sed -E "s#-fsanitize=fuzzer-no-link#-fsanitize=fuzzer#")
case "$LINK" in
    *"-o $OUT/fuzz_fprime"*) ;;
    *) echo "link command rewrite failed" >&2; exit 1 ;;
esac
eval "$LINK \"$OUT/fuzz_fprime_harness.o\" -fsanitize=fuzzer"
test -x "$OUT/fuzz_fprime" || { echo "link produced no binary" >&2; exit 1; }

echo "built $OUT/fuzz_fprime"
