#!/usr/bin/env bash
# Kernel mode: .ARRAY/.DIRECTORY/.LIST and message sends are the interpreter's real objects. Skips without RX2CPP_KERNEL.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ -n "${RX2CPP_KERNEL:-}" ]] || { echo "SKIP kernel objects (set RX2CPP_KERNEL to a kernel work dir)"; exit 0; }
OO_ROOT=${OO_ROOT:-/usr/local}; REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cat > "$T/o.rex" <<'EOR'
a = .array~of(10,20,30)
say a~items a~at(2)
d = .directory~new
d~put("hello","k")
say d~at("k") d~items
l = .list~new
l~append("x"); l~append("y")
say l~items l~firstitem
say a~at(2) + 5
say a~class~id
EOR
"$REXX_BIN" "$T/o.rex" > "$T/ref.out"
"$ROOT/build.sh" "$T/o.rex" "$T/o.bin" >/dev/null 2>&1
(cd "$T" && ./o.bin > nat.out)
cmp "$T/ref.out" "$T/nat.out" || { echo "FAIL kernel objects"; diff "$T/ref.out" "$T/nat.out"; exit 1; }
echo "PASS kernel objects: array, directory, list, class messages identical to the interpreter"
