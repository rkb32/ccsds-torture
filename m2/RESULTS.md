# M2 results (2026-11-06)

Model: Haiku 5.5 (main work). No Opus check needed; no decisions taken.
Engine: real libFuzzer, clang 18.1.3, fprime devel @3556871d6fd5d94b6f148a394ba0b6c67e84f897.
Sanitizers: `-fsanitize=address,undefined,leak` confirmed in `fprime/build-fuzz/build.ninja` (verified).
Run: `ASAN_OPTIONS=detect_leaks=0`, `-max_total_time=3600`, one run per target.

| Target | Execs | Avg exec/s | Peak RSS | New units | Final cov / corpus | Crashes |
|---|---|---|---|---|---|---|
| `fuzz_spd` (SpacePacketDeframer) | 46,090,735 | 12,799 | 579 MB | 0 | 1655 / 7 | 0 |
| `fuzz_fprime` (FprimeDeframer) | 50,600,330 | 14,051 | 548 MB | 14 | 1531 / 18 | 0 |

Verified: both logs end with `DONE`, exit code 0, no `ERROR:` or `SUMMARY:` lines. `out/*/crash/` has no files.

## Triage
No crashes, so nothing to classify. No F' `FW_ASSERT` fired in either run.

## Findings from reading source (verified)
- SPD (`SpacePacketDeframer.cpp:37-128`): every reject path returns early with an event and no assert. The length check at line 87 cannot underflow because line 54 guarantees size > 6.
- FPD (`FprimeDeframer.cpp`): asserts at lines 44, 72, 84, 86. Out of scope per F' #5923. None fired.
- FPD start word is `0xdeadbeef` (`Svc/FprimeProtocol/FprimeProtocol.fpp:11`).

## Open questions
## Follow-up (2026-11-07, after Opus review)
1. **Input that reached line 110 (verified).** A replay probe (`CT_REPLAY=1`, `harness/fuzz_fprime.cpp`) over `seeds_spd` finds one hit out of 162: `seeds_spd/097768a382579186df70cf9b8544d24d7842042f` (21 bytes). It was written about six minutes into the FPD run. Its CRC trailer `b0 82 38 bb` equals the run's recommended dictionary entry (`\260\2028\273`, "Uses: 4294611"). So the valid CRC came from libFuzzer's comparison-derived dictionary, not from chance. Mechanism: verified by file contents; the dictionary-to-compare link is inferred.
2. **Start word (partly verified; counts corrected 2026-11-07).** 20 files in `seeds_spd` start with `DE AD BE EF`. By mtime, 6 predate the 1h run (16:22:29–16:22:56; run start ≈16:23:16, inferred from log end 17:23:17 minus 3600 s) and 14 are later. The earlier "8 pre-run / 12 during-run" counts were wrong. The 6 pre-run files likely came from a short run just before (inferred, unverified).
3. **Framed seeds (verified).** `make_framed_seeds.py` (zlib CRC-32, big-endian trailer, matching `Utils::Hash` and `FprimeDeframerTester::injectChecksum`): 125/125 framed seeds reach dataOut. Unframed `../m1/seeds`: 0/125.
4. **Build note (verified).** The binary is built with `--coverage`, so it writes `.gcda` files at exit. Concurrent runs corrupt each other's profiles (warnings only), so `experiments.sh` gives each run its own `GCOV_PREFIX`.

## Experiments (2026-11-07, Haiku 5.5; Opus 5.5 review set the design)
Each run: fresh writable corpus, read-only seeds, `GCOV_PREFIX` per run. "Reach dataOut" = replay probe (`replay_fprime.sh`) on the final corpus.

| Run | Seeds | Length | Execs | Final cov / corpus | New units | Files starting DE AD BE EF | Files reaching dataOut | Crashes |
|---|---|---|---|---|---|---|---|---|
| fprime_framed | seeds_framed_ro (125) | 3600 s | 27,752,619 | 1532 / 16 | 25 | 9 of 11 | 0 of 11 | 0 |
| fprime_none | ../m1/seeds (125) | 3600 s | 29,857,072 | 1534 / 21 | 26 | 17 of 20 | 2 of 20 | 0 |
| fprime_cmp0 | ../m1/seeds | 900 s, `-use_cmp=0` | 6,949,136 | 1083 / 3 | 1 | 0 of 1 | 0 of 1 | 0 |
| fprime_cmp1 | ../m1/seeds | 900 s, `-use_cmp=1` | 6,981,292 | 1529 / 15 | 16 | 12 of 13 | 1 of 13 | 0 |

Verified: all four logs end with `DONE`; no `ERROR:` lines; crash dirs empty; counts above come from the logs and replay.

Findings:
- **Comparison feedback: start word replicates; valid frame does not.** CMP off made 0 start-word files in every run (cov ~1085). CMP on made 9–12 per run, in 4 of 4 runs (see repeat trials). The single valid frame from the first cmp1 run did not reproduce in 3 repeats (0 of 3). So CMP appears to drive start-word learning. The valid frame is one unreplicated hit. CMP-off also explores far less, so the arms differ in more than CMP.
- **Unframed seeds can yield valid frames (verified, small).** The 1h unframed run made 2 files that reach dataOut, from 0 valid seeds. Start-word learning happened there too.
- **Framed seeds do not make valid new units (verified).** 25 coverage-new units, none reaching dataOut. Likely cause: mutation breaks the CRC or length (inferred, not checked).
- **File counts < "New units".** libFuzzer's reduce step replaces files (REDUCE lines in logs). Inferred, not checked.

## Repeat trials (2026-11-07, Haiku 5.5)
Six 900 s runs, unframed seeds (`../m1/seeds`), seeds 1–3 per arm, all in parallel. Script: `trials.sh`. Replay: `replay_fprime.sh`.

| Trial | Execs | Final cov | New units | Files | Start-word files | Reach dataOut | Crashes |
|---|---|---|---|---|---|---|---|
| cmp0_s1 | 5,088,149 | 1087 | 1 | 1 | 0 | 0 | 0 |
| cmp0_s2 | 5,387,933 | 1082 | 1 | 1 | 0 | 0 | 0 |
| cmp0_s3 | 5,169,480 | 1085 | 2 | 2 | 0 | 0 | 0 |
| cmp1_s1 | 5,101,372 | 1411 | 19 | 11 | 10 | 0 | 0 |
| cmp1_s2 | 5,359,862 | 1413 | 23 | 12 | 10 | 0 | 0 |
| cmp1_s3 | 4,816,507 | 1411 | 16 | 10 | 9 | 0 | 0 |

Verified: all six logs reached `DONE`; the watcher matched no errors or sanitizer lines; crash dirs empty; counts from replay.

- **Start word:** CMP on gives 9–10 start-word files per run (3 of 3). CMP off gives 0 (3 of 3). Replicated.
- **Valid frame:** 0 of 3 CMP-on repeats reach dataOut. The earlier CMP-on hit did not reproduce. Across all 9 unframed runs (~75M execs), 3 files reach dataOut: 2 from the 1h run, 1 from the first cmp1 run. Rare (sum of exec counts from logs).
- **Coverage:** CMP-off stays at 1082–1087; CMP-on reaches 1411–1413. Verified from logs.
- **Files < new units** again (reduce step). Inferred, not checked.

## Limits
- SPD coverage was flat at 1655 from exec 150 to 46M. The mutator adds no new branches, so either the seeds already cover them or most inputs stop at early checks. Medium confidence. Not tested.
- Both runs used `seeds_spd` as corpus dir, and libFuzzer writes new units there. The runs are not independent. The FPD run started from 149 files, not the 125 in M1. Attribution of the extra 24 to smoke runs is unverified.
- FPD seeds are CCSDS-shaped, not F' frames. Most random inputs will fail the start-word check.
- Harness uses `#define protected public` (SPD). `detect_leaks=0` because the tester is leaked on purpose.
- One hour per target. This is not evidence that no bug exists.

## Files
- `out/spd/run1h.log`, `out/fprime/run1h.log`: run logs.
- `harness/fuzz_spd.cpp`, `harness/fuzz_fprime.cpp`: harnesses.
- `build_spd_fuzz.sh`, `build_fprime_fuzz.sh`: build scripts.
