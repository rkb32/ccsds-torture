#!/usr/bin/env python3
"""Wrap each seed as an F' frame: start word DE AD BE EF, 4-byte big-endian length, body, CRC-32 (big-endian).

CRC is CRC-32/IEEE 802.3 over header+body (zlib.crc32), matching Utils::Hash in fprime/Utils/Hash/Crc32 and
FprimeDeframerTester::injectChecksum. Validity is checked by replay_fprime.sh, not assumed.
Usage: make_framed_seeds.py <src_dir> <dst_dir>
"""
import os
import struct
import sys
import zlib

START_WORD = b"\xde\xad\xbe\xef"
MAX_BODY = 512

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
count = 0
for name in sorted(os.listdir(src)):
    path = os.path.join(src, name)
    if not os.path.isfile(path):
        continue
    with open(path, "rb") as fh:
        body = fh.read()[:MAX_BODY]
    frame = START_WORD + struct.pack(">I", len(body)) + body
    frame += struct.pack(">I", zlib.crc32(frame) & 0xFFFFFFFF)
    with open(os.path.join(dst, "f_" + name), "wb") as out:
        out.write(frame)
    count += 1
print("wrote", count)
