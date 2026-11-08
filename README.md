# ccsds-torture (DRAFT, not for public release)

Robustness and fuzzing tests for CCSDS Space Packet parsers.

## Status
- **F´ (done so far):** libFuzzer harnesses for `SpacePacketDeframer` and `FprimeDeframer`, built with ASan and UBSan. Oracle: sanitizers and aborts only. F´ asserts are out of scope (F´ #5923). Runs of up to one hour found no crashes. Results: `m2/RESULTS.md`.
- **Scope:** F´ only. cFE is not covered in this repo.
- **Regression tests:** `m2/tests/regress.py` (probe and fuzz smoke checks).

## Layout
- `m2/harness/`: F´ harnesses.
- `m2/build_fprime_fuzz.sh`, `m2/build_spd_fuzz.sh`: build scripts (WSL Ubuntu 24.04, clang 18).
- `m2/trials.sh`, `m2/trials_1h.sh`, `m2/experiments.sh`, `m2/checks.sh`: run scripts.
- `m2/replay_fprime.sh`: counts inputs that reach the F´ `dataOut` path.

## Requirements
- F´ checkout at devel SHA `3556871d6fd5d94b6f148a394ba0b6c67e84f897`. Not vendored here.
- WSL Ubuntu 24.04 with clang 18 and ninja.
