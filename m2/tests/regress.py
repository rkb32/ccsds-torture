#!/usr/bin/env python3
"""Regression tests for the F-prime deframer and SpacePacketDeframer harnesses.

Run inside WSL from anywhere:  python3 m2/tests/regress.py
Needs the built binaries: out/fprime/fuzz_fprime and out/spd/fuzz_spd (see build_*.sh).

Checks:
  1. Probe (CT_REPLAY=1): a correctly framed input reaches dataOut; bad start word,
     bad CRC, and bad length do not.
  2. Fuzz smoke: each harness runs 20,000 inputs from a generated corpus with exit 0,
     no sanitizer report, and no libFuzzer ERROR line.
Inputs are generated here. No seed files are read from outside this folder.
"""
import os
import struct
import subprocess
import sys
import tempfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
M2 = os.path.dirname(HERE)
FPRIME = os.path.join(M2, "out", "fprime", "fuzz_fprime")
SPD = os.path.join(M2, "out", "spd", "fuzz_spd")
START = b"\xde\xad\xbe\xef"
RUNS = 20000

failures = []


def check(name, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + name + (f" ({detail})" if detail else ""))
    if not ok:
        failures.append(name)


def fprime_frame(body, start=START, length_delta=0, bad_crc=False):
    frame = start + struct.pack(">I", len(body) + length_delta) + body
    crc = zlib.crc32(frame) & 0xFFFFFFFF
    if bad_crc:
        crc ^= 0x1
    return frame + struct.pack(">I", crc)


def ccsds_packet(apid, data):
    # Primary header: version 0, type 0 (TM), no secondary header, seq flags 3, count 0.
    word1 = apid & 0x07FF
    word2 = 0xC000
    word3 = len(data) - 1
    return struct.pack(">HHH", word1, word2, word3) + data


def probe_hits(path):
    env = dict(os.environ, CT_REPLAY="1", ASAN_OPTIONS="detect_leaks=0")
    r = subprocess.run([FPRIME, path], env=env, capture_output=True, text=True)
    text = r.stdout + r.stderr
    return r.returncode, text.count("DATAOUT_HIT")


def fuzz(binary, corpus_dir, out_dir, label):
    os.makedirs(out_dir, exist_ok=True)
    env = dict(os.environ, ASAN_OPTIONS="detect_leaks=0")
    r = subprocess.run(
        [binary, f"-runs={RUNS}", "-seed=1", "-print_final_stats=1", out_dir, corpus_dir],
        env=env, capture_output=True, text=True,
    )
    text = r.stdout + r.stderr
    sanitizer = any(s in text for s in ("AddressSanitizer", "UndefinedBehaviorSanitizer", "runtime error", "LeakSanitizer"))
    error_line = any(line.startswith("ERROR:") for line in text.splitlines())
    done = f"Done {RUNS} runs" in text
    check(
        f"{label}: {RUNS} runs, exit 0, no sanitizer report, no ERROR line",
        r.returncode == 0 and not sanitizer and not error_line and done,
        f"rc={r.returncode}, done={done}, sanitizer={sanitizer}, error_line={error_line}",
    )
    if r.returncode != 0 or sanitizer or error_line or not done:
        print(text)


def main():
    if not (os.path.isfile(FPRIME) and os.path.isfile(SPD)):
        print("missing binaries; build first (build_fprime_fuzz.sh, build_spd_fuzz.sh)")
        return 2

    with tempfile.TemporaryDirectory() as tmp:
        # 1. Probe tests
        body = bytes.fromhex("0801c0000003") + b"abcd"
        cases = {
            "valid framed input reaches dataOut": (fprime_frame(body), True),
            "bad start word does not reach dataOut": (fprime_frame(body, start=b"\x00\x00\x00\x00"), False),
            "bad CRC does not reach dataOut": (fprime_frame(body, bad_crc=True), False),
            "length field off by one does not reach dataOut": (fprime_frame(body, length_delta=1), False),
        }
        for name, (data, expect_hit) in cases.items():
            path = os.path.join(tmp, name.replace(" ", "_"))
            with open(path, "wb") as fh:
                fh.write(data)
            rc, hits = probe_hits(path)
            hit = hits > 0
            check(name, hit == expect_hit and rc == 0, f"rc={rc}, DATAOUT_HIT lines={hits}")

        # 2. Fuzz smoke tests on generated corpora (read-only input dir, writable out dir)
        fprime_corpus = os.path.join(tmp, "fprime_seeds")
        os.makedirs(fprime_corpus)
        for i, b in enumerate([body, b"x" * 10, b"\x00" * 20, b"\xff" * 33]):
            with open(os.path.join(fprime_corpus, f"s{i}"), "wb") as fh:
                fh.write(fprime_frame(b))
        fuzz(FPRIME, fprime_corpus, os.path.join(tmp, "fprime_out"), "fuzz_fprime")

        spd_corpus = os.path.join(tmp, "spd_seeds")
        os.makedirs(spd_corpus)
        for i, data in enumerate([b"\x01" * 8, b"\x02" * 50, b"\x03" * 1, b"\x04" * 300]):
            with open(os.path.join(spd_corpus, f"p{i}"), "wb") as fh:
                fh.write(ccsds_packet(0x001 + i, data))
        fuzz(SPD, spd_corpus, os.path.join(tmp, "spd_out"), "fuzz_spd")

    print()
    print("FAILED: " + ", ".join(failures) if failures else "ALL PASSED")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
