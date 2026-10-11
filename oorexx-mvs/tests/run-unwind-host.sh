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

for scenario in ("--uncaught", "--bad-pop", "--double-pop", "--duplicate-push", "--invalid-type"):
    r = subprocess.run([sys.argv[1], scenario],
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                       preexec_fn=no_core, check=False)
    if r.returncode != -signal.SIGABRT:
        raise SystemExit("FAIL %s expected SIGABRT, got %d" % (scenario, r.returncode))
    print("PASS %s fails closed with SIGABRT (host mock)" % scenario)
PYHOST
