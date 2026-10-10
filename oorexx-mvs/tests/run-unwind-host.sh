#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
OUT="${TMPDIR:-/tmp}/rx_mvs_dev17_unwind_$$"
trap 'rm -f "$OUT" core core.*' EXIT HUP INT TERM
"${CXX:-c++}" -std=c++11 -Wall -Wextra -pedantic "$ROOT/tests/unwind_chain_test.cpp" -o "$OUT"
"$OUT"
# Python inspects the terminating signal without noisy shell abort messages.
python3 - "$OUT" <<'PYHOST'
import resource
import signal
import subprocess
import sys

def no_core():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))

r = subprocess.run([sys.argv[1], "--uncaught"],
                   stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                   preexec_fn=no_core, check=False)
if r.returncode != -signal.SIGABRT:
    raise SystemExit("FAIL uncaught expected SIGABRT, got %d" % r.returncode)
print("PASS unmatched activation terminates with SIGABRT (host mock)")
PYHOST
