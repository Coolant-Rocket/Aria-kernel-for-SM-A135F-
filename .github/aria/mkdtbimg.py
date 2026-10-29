#!/usr/bin/env python3
"""Wrap a single DTB into an Android dt_table image (dtb.img), same layout as A135F-Unbound's dtb.img:
32 byte header + 1 entry (custom1=0xff000000) + dtb, page_size 2048."""
import struct, sys
src, dst = sys.argv[1], sys.argv[2]
dtb = open(src, 'rb').read()
assert dtb[:4] == b'\xd0\x0d\xfe\xed', 'not a DTB'
total = 64 + len(dtb)
hdr = struct.pack('>8I', 0xd7b7ab1e, total, 32, 32, 1, 32, 2048, 0)
ent = struct.pack('>8I', len(dtb), 64, 0, 0, 0, 0xff000000, 0, 0)
open(dst, 'wb').write(hdr + ent + dtb)
