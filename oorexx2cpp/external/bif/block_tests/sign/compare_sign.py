#!/usr/bin/env python3
"""Test-only oracle comparison: U = deliberately unqualified native exponent case."""
from pathlib import Path
import sys
oracle=Path(sys.argv[1]).read_text().splitlines()
native=Path(sys.argv[2]).read_text().splitlines()
if len(oracle)!=len(native):
    raise SystemExit(f'row count mismatch {len(oracle)} vs {len(native)}')
wrong=[(i,o,n) for i,(o,n) in enumerate(zip(oracle,native),1) if n!='U' and o!=n]
unsupported=native.count('U')
print(f'qualified {len(oracle)-unsupported}/{len(oracle)}; unqualified {unsupported}; mismatches {len(wrong)}')
if wrong:
    print('first mismatches:',wrong[:10]); raise SystemExit(1)
if unsupported == 0 or (len(oracle)-unsupported)<10000:
    raise SystemExit('unexpectedly small native subset coverage')
