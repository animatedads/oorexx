#!/usr/bin/env bash
# Uses system ooRexx, or explicit REXX_BIN and REXX_LIB (for standalone .deb).
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REXX_BIN=${REXX_BIN:-rexx}
# Dynamic BIF catalogue discovery. A bundled independent pack is preferred,
# but a different release can be injected without changing compiler classes.
if [[ "${RX2CPP_BIF_DISABLED:-0}" != 1 && -z "${RX2CPP_BIF_ROOT:-}" && -f "$ROOT/external/bif/catalog/bifs.tsv" ]]; then
    export RX2CPP_BIF_ROOT="$ROOT/external/bif"
fi
if [[ "${RX2CPP_BIF_DISABLED:-0}" == 1 ]]; then unset RX2CPP_BIF_ROOT; fi
export REXX_PATH="$ROOT${REXX_PATH:+:$REXX_PATH}"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
exec "$REXX_BIN" "$ROOT/rx2cpp.rex" "$@"
