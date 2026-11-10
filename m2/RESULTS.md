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

## Follow-up (2026-11-07, after Opus review)
1. **Input that reached line 110 (verified).** A replay probe (`CT_REPLAY=1`, `harness/fuzz_fprime.cpp`) over `seeds_spd` finds one hit out of 162: `seeds_spd/097768a382579186df70cf9b8544d24d7842042f` (21 bytes). It was written about six minutes into the FPD run. Its CRC trailer `b0 82 38 bb` equals the run's recommended dictionary entry (`\260\2028\273`, "Uses: 4294611"). So the valid CRC came from libFuzzer's comparison-derived dictionary, not from chance. Mechanism: verified by file contents; the dictionary-to-compare link is inferred.
2. **Start word (partly verified; counts corrected 2026-11-07).** 20 files in `seeds_spd` start with `DE AD BE EF`. By mtime, 6 predate the 1h run (16:22:29–16:22:56; run start ≈16:23:16, inferred from log end 17:23:17 minus 3600 s) and 14 are later. The earlier "8 pre-run / 12 during-run" counts were wrong. The 6 pre-run files match the FPD smoke run. `out/fprime/smoke.log` (31 s, 13 new units) was last written at 16:22:57, right after the last of them. Verified: timing and log. Inferred: the smoke run wrote into `seeds_spd`; its log doesn't name the corpus dir. The 14 later files are from the 1h FPD run: the SPD 1h run had 0 new units, so it wrote nothing (verified, `out/spd/run1h.log`).
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
- **File counts < "New units":** now verified (see Checks). With `reduce_inputs=1` the corpus keeps fewer files than new units; with `=0` they match.

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
- **Files < new units:** same reduce effect as the Checks section below. Verified.

## 1-hour repeat trials (2026-11-07, Haiku 5.5)
Six 3600 s runs, unframed seeds (`../m1/seeds`), seeds 1–3 per arm. Script: `trials_1h.sh`. Replay: `replay_fprime.sh`.

| Trial | Execs | Final cov | New units | Start-word files | Reach dataOut | Slow-unit artifacts |
|---|---|---|---|---|---|---|
| cmp0_s1 | 17,534,599 | 1086 | 1 | 0 | 0 | 1 |
| cmp0_s2 | 17,791,113 | 1085 | 1 | 0 | 0 | 1 |
| cmp0_s3 | 17,766,115 | 1083 | 2 | 0 | 0 | 1 |
| cmp1_s1 | 17,365,989 | 1411 | 21 | 11 | 0 | 1 |
| cmp1_s2 | 18,560,785 | 1531 | 28 | 15 | 1 | 0 |
| cmp1_s3 | 16,704,989 | 1527 | 17 | 10 | 0 | 0 |

- **Verified:** no sanitizer errors and no crashes in any run.
- **Verified (logs):** four runs wrote `slow-unit` files. All six runs reported 4,264–4,269 s instead of 3,600 s. Slowest units: 1,503 s (cmp0_s1); 806 s (cmp0_s2, cmp0_s3, cmp1_s1); cmp1_s2 and cmp1_s3 had none.
- **Unverified:** replay time (~2 s). The replay files record only exit codes and hashes.
- **Cause (inferred, not established):** Kernel-Power standby 15:29:11–15:42:41 on 2026-11-07 (about 810 s) ends 4 s before the cmp0 batch finished and is close to the 806 s figure. No standby falls in the cmp1 batch window (about 18:08–19:19 on 2026-11-08), so host sleep does not explain all six.
- **Start word:** replicated. cmp0 0 of 3 runs; cmp1 10–15 files per run.
- **Valid frame:** cmp1 1 of 3 runs (cmp1_s2, one file). cmp0 0 of 3.
- **Pooled, unframed seeds:** valid frames in 3 of 8 comparison-on runs (`fprime_none`, `fprime_cmp1`, and cmp1_s2 at 1 h) and 0 of 7 comparison-off runs. Exact one-sided p ≈ 0.12. Suggestive only; the counts are small.

## Checks (2026-11-07, Haiku 5.5)
120 s runs, fixed seed 1, unframed seeds (`../m1/seeds`). Script: `checks.sh`. No crashes.

| Check | Config | Execs | Final cov | New units | Files |
|---|---|---|---|---|---|
| reduce on | fuzz_fprime `-reduce_inputs=1` | 654,360 | 1413 | 14 | 10 |
| reduce off | fuzz_fprime `-reduce_inputs=0` | 820,113 | 1410 | 12 | 12 |
| SPD value profile off | fuzz_spd `-use_value_profile=0` | 585,954 | 1661 | 15 | 14 |
| SPD value profile on | fuzz_spd `-use_value_profile=1` | 36,173 | 1657 | 369 | 169 |

- **Verified:** `-help=1` on both binaries: `use_value_profile` default 0, `reduce_inputs` default 1.
- **Verified:** reduce explains "files < new units". With reduce off, files equal units.
- **Verified:** value profile gives no coverage gain in 120 s. It ran about 16x fewer execs. Not a fair speed comparison, but it doesn't break the plateau.

## Research follow-ups (2026-11-08, Haiku 5.5; Opus 5.5 decision check)
- **SPD plateau (coverage verified, cause inferred).** gcov on `SpacePacketDeframer.cpp`, counts cumulative across all runs linked to this build: 55 of 61 lines executed (90.2%). Never executed: the destructor (line 21) and the deserialize-failure branch (lines 66–72). Line 54 guarantees size > 6. The header is three U16 reads, and each read fails only when fewer than 2 bytes remain (source read: `Fw/Types/Serializable.cpp` 310–330; fresh deserializer at offset 0: `Serializable.cpp:41`, `Buffer.cpp:165`). So lines 66–72 cannot run from `dataIn` (verified by source reading; not tested). The flat 1655 is saturation of reachable code, not a mutator gap.
- **Stall (overrun verified, cause inferred).** All six 1 h trial runs (`trials1h/`) overran by 664–669 s (elapsed 4264–4269 s vs 3600 s). The overrun is nearly identical across the six parallel runs, which points to one shared suspend (inferred). The 1 h runs `fprime_none`, `fprime_framed`, and `fprime/run1h.log` ran at 3601 s, so they did not overrun. Kernel-Power 506 ("entering Modern Standby") and 507 ("exiting Modern Standby") are verified by message text. They do not explain the overruns. The repeat batch had a standby from 09:47:11 to 10:08:46 inside a window where all six runs reported exactly 3601 s (window = log mtime minus 3601 s; mtime-as-end is assumed). So standby alone does not cause overrun. Cause unverified. `m2/checkbudget.sh` flags these overruns.
- **Correction (2026-11-08).** The earlier note said three runs overran. All six did. The earlier count was wrong.
- **Start-word origin (verified by log and test).** `out/fprime/smoke.log` has one corpus line: "140 files found in seeds_spd". libFuzzer prints one line per corpus dir, including empty ones (`scratchpad/writetest/run.log`). So seeds_spd was the only corpus dir, and new units went there. Write-target test: 20,000 runs; empty dir A got 2 new files; dir B kept 125 files (libFuzzer loaded 124) with an unchanged hash. The exact smoke command is still unlogged.
- **Valid-frame gate (per-run counts verified; mechanism inferred).** Counts from each run's own `FprimeDeframer.cpp.gcda` (line 98 = CRC check, line 110 = dataOut):
  - CMP off (7 of 18 runs): the CRC check was never reached. The start-word gate binds.
  - CMP on, checks but no valid CRC (6 runs, 18k–1.1M checks): `checks/red0`, `checks/red1`, `trials/cmp1_s1–s3`, `trials1h/cmp1_s1`.
  - CMP on, valid CRC found (5 runs): `fprime_cmp1` 1,489; `trials1h/cmp1_s2` 6,297; `trials1h/cmp1_s3` 12,134; `fprime_none` 37,360; `fprime_framed` 172,682 (framed seeds).
  - Reproducibility is therefore whether a run finds one valid CRC. Once it does, later mutations keep passing (inferred from the counts, not tested).
  - Not re-run. The Opus gate was not cleanly met. Extra runs cost about 1 h wall-clock per batch.
- **Public prep.** Username paths replaced with `$HOME` in 13 tracked logs (84 matches before, 0 after; verified by grep). Not committed.

## Repeat CMP-on 1 h trials, seeds 4–9 (2026-11-09, Haiku 5.5; Opus 5.5 pick A)
- Setup: six parallel `fuzz_fprime -use_cmp=1 -max_total_time=3600`, seeds 4–9, input `m1/seeds`. Script `m2/repeat_cmp1_1h.sh` (untracked, not committed). All six ran 3601 s (`checkbudget` ok; verified).
- No crash-* files in any run (verified by listing). The old script `crashes` column counted slow-unit files too. Fixed: `crashes` and `slow_units` are now separate (verified on these dirs: 0 crashes; 1 slow unit each in s7, s8). libFuzzer wrote one per run (s7, s8) at "Slowest unit: 11 s". Replayed once each: exit 0, 47 ms and 67 ms, no sanitizer output (verified). Cause unverified. The FPD hash loop is bounded by the 74-byte input, and `dataIn_handler` uses only locals (source read: `FprimeDeframer.cpp` 28–111). The harness tester persists across calls, but its history is cleared each call (`fuzz_fprime.cpp:44`). Power events do not match (see the stall note above).
- Valid-frame counts (gcov counts executions; replay counts distinct inputs):

| Run | Execs | Corpus files | Replay dataOut files | gcov CRC checked | gcov CRC pass | gcov dataOut |
|---|---|---|---|---|---|---|
| s4 | 27,073,604 | 14 | 1 | 926,195 | 80 | 80 |
| s5 | 27,717,634 | 13 | 1 | 1,002,758 | 874 | 874 |
| s6 | 26,731,205 | 11 | 0 | 929,513 | 0 | 0 |
| s7 | 28,600,365 | 13 | 1 | 1,445,232 | 2,119 | 2,119 |
| s8 | 28,872,440 | 14 | 1 | 1,519,468 | 505 | 505 |
| s9 | 28,443,296 | 13 | 1 | 1,709,952 | 1,688 | 1,688 |

- Five of six runs reached dataOut. The gcov and replay zero/non-zero pattern matches (verified). Earlier mix: 5 of 11 CMP-on runs had a valid CRC. Both are small samples, so the rate is not established.

## Stall rerun, seeds 7 and 8 plus control 4, 1 h (2026-11-09, Haiku 5.5)
- Setup: `m2/stall_test_1h.sh` (untracked). Same fuzz flags as `repeat_cmp1_1h.sh`, a wall-clock stamp on every log line, and a 1 Hz heartbeat. Three parallel runs, 12:07–13:08.
- All three ran 3601 s. 0 slow units and 0 crash files (verified by logs and listing). Exec counts 42.3M–43.9M. That is above the 6-parallel batch (27–29M), so the counts are not comparable.
- Heartbeat: no gap over 2 s across the full hour (verified with `date -f` scan). No host stall was visible during this run.
- Determinism: same-seed status lines diverge from the original runs by the first pulse (#65536: ft 1108 vs 1109) and differ from #131072 on. So the same seed does not reproduce the same trajectory here (verified by log comparison; cause unverified). The 11 s units therefore could not be tested against the same inputs.
- The original 2026-11-09 slow-unit runs had no heartbeat log, so the stall hypothesis cannot be checked against them.
- Conclusion: the 11 s slow units did not recur, and this hour showed no stall. The cause of the original units remains unverified.

## Determinism and slow-unit replay (2026-11-09, Haiku 5.5)
- Same seed (7), 300k runs, two runs per arm. ASLR on: the two runs differ at the first pulse (#65536 cov 1085 vs 1084) and later. ASLR off (`setarch -R`): the two runs are identical at #65536, #131072, and #262144 (verified; small sample).
- Slow-unit replay: each 11 s input replayed 20 times per arm, each in a fresh process. Two replay runs, 20 per arm each. Run 1 max 155 ms. Run 2 max 90 ms (ASLR on, `c78e37`); run 2 per arm: `c460162` 63 ms on / 34 ms off, `c78e37` 90 ms on / 49 ms off. No replay came near 11 s in either run (verified for run 2; run 1 per-arm split not re-checked).
- So the 11 s time does not come from a fresh process on these inputs. The cause is still unverified; it may depend on state in the long-running process. The ASLR-off hour run is in the next section.

## One-hour ASLR-off run, seed 7 (2026-11-09, Haiku 5.5)
- Script: `m2/aslr_1h_s7.sh` (not committed). One run, alone, `setarch -R`, `-max_total_time=3600`, same flags as the batch.
- Result (verified in logs): exit 0; 7,296,424 execs; libFuzzer reported 11,380 s against a 3,600 s budget. Slowest units 1,788 s and 9,070 s. No 11 s unit.
- Wall clock agrees (verified): run directory created 20:15:16, last log write 23:24:56, which is 11,380 s. So the overrun is real, not a clock error.
- The 1,788 s unit matches a Windows standby from 20:23:47 to 20:53:40 (1,793 s, Kernel-Power 506/507, verified). Link inferred.
- The 9,070 s unit has no matching sleep. By subtraction it starts near 20:53:46, when a sleep/resume (20:53:45–20:53:47) happened. Inferred, not verified.
- Both inputs replayed in a fresh process: exit 0, 1.5 s and 1.7 s wall including startup (verified). The input alone is not slow.
- Batch `cmp1_s7` (ASLR on, six runs in parallel) had 28,600,365 execs in 3,601 s and its slowest unit was 11 s. Pulses diverge at #131072 (1373 vs 1372), so this run is not the same path.
- Cause of the long stalls: not established. A host or VM freeze fits both units better than the input, but that is unproven.

## Limits
- SPD coverage was flat at 1655 from exec 150 to 46M. The mutator adds no new branches, so either the seeds already cover them or most inputs stop at early checks. Medium confidence. A 2-min value-profile test gave no gain (see Checks). Cause still untested.
- Both runs used `seeds_spd` as corpus dir, and libFuzzer writes new units there. The runs are not independent. The FPD run started from 149 files, not the 125 in M1. Attribution of the extra 24 to smoke runs is unverified.
- FPD seeds are CCSDS-shaped, not F' frames. Most random inputs will fail the start-word check.
- Harness uses `#define protected public` (SPD). `detect_leaks=0` because the tester is leaked on purpose.
- One hour per target. This is not evidence that no bug exists.

## Files
- `out/spd/run1h.log`, `out/fprime/run1h.log`: run logs.
- `harness/fuzz_spd.cpp`, `harness/fuzz_fprime.cpp`: harnesses.
- `build_spd_fuzz.sh`, `build_fprime_fuzz.sh`: build scripts.
