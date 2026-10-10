#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if (( $# != 2 )); then echo "Usage: $0 SOURCE.cls OUTPUT_PREFIX" >&2; exit 64; fi
export REXX_PATH="$ROOT${REXX_PATH:+:$REXX_PATH}"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
exec "${REXX_BIN:-rexx}" "$ROOT/rx2cpp_hybrid.rex" "$@"
