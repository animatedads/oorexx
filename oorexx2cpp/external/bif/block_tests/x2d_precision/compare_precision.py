#!/usr/bin/env python3
"""Test-only exact-value and error-vs-value oracle. U is a typed deferred case."""
from pathlib import Path
import sys
reference = Path(sys.argv[1]).read_bytes().splitlines()
native = Path(sys.argv[2]).read_bytes().splitlines()
if len(reference) != 8982 or len(native) != len(reference):
    raise SystemExit(f'unexpected case count: oracle={len(reference)} native={len(native)}')
failures = [(i + 1, a, b) for i, (a, b) in enumerate(zip(reference, native))
            if b != b'U' and a != b]
deferred = native.count(b'U')
qualified = len(native) - deferred
print(f'X2D oracle exact: {qualified}/{len(reference)} native, {deferred} typed-deferred, {len(failures)} mismatches')
if failures:
    print('first mismatches:', failures[:8])
    raise SystemExit(1)
if deferred != 3615 or qualified != 5367:
    raise SystemExit('typed-defer classification changed; inspect intended coverage before updating tests')
