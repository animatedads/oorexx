#!/usr/bin/env bash
# Runs ooRexx precompiler, then the selected native C++ compiler.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if (( $# < 2 || $# > 3 )); then
    printf 'Usage: %s INPUT.rex OUTPUT_NATIVE [OUTPUT.cpp]\n' "$0" >&2
    exit 64
fi
input=$1
native=$2
cpp=${3:-${native}.cpp}
mkdir -p "$(dirname -- "$cpp")" "$(dirname -- "$native")"
if [[ "${RX2CPP_BIF_DISABLED:-0}" != 1 && -z "${RX2CPP_BIF_ROOT:-}" && -f "$ROOT/external/bif/catalog/bifs.tsv" ]]; then
    export RX2CPP_BIF_ROOT="$ROOT/external/bif"
fi
if [[ "${RX2CPP_BIF_DISABLED:-0}" == 1 ]]; then unset RX2CPP_BIF_ROOT; fi
"$ROOT/run-compiler.sh" "$input" "$cpp"
extra=( )
if [[ -n "${RX2CPP_BIF_ROOT:-}" ]]; then
    bif="$RX2CPP_BIF_ROOT"
    [[ -f "$bif/catalog/bifs.tsv" && -f "$bif/native/rxbif_breadth.cpp" ]] || {
        echo "rx2cpp: invalid RX2CPP_BIF_ROOT" >&2; exit 65;
    }
    extra+=( -I"$bif/native" -I"$bif/variables" "$bif/native/rxbif.cpp"
             "$bif/native/rxbif_breadth.cpp" "$bif/variables/rxbif_variables.cpp" )
    if [[ "${RX2CPP_BIF_ISOLATED:-0}" == 1 ]]; then
        : "${OO_ROOT:?ooRexx root required for detached BIF execution}"
        extra+=( -DRX2CPP_BIF_ISOLATED -I"$OO_ROOT/include" "$bif/native/rxbif_oorexx_bridge.cpp"
                 -L"$OO_ROOT/lib" -Wl,-rpath,"$OO_ROOT/lib" -lrexx -lrexxapi )
    fi
fi
if grep -q rx_extlib_bridge "$cpp"; then   # ::REQUIRES ... LIBRARY: host needs oorexxapi.h (headers only) and libdl
    : "${OO_ROOT:?OO_ROOT (ooRexx install with include/oorexxapi.h) is required for ::REQUIRES LIBRARY}"
    extra+=( -I"$OO_ROOT/include" -ldl )
fi
"${CXX:-g++}" -std=c++17 -O2 -Wall -Wextra -Werror -I"$ROOT/include" "$cpp" "${extra[@]}" -o "$native"
printf 'Native executable: %s (generated C++: %s)\n' "$native" "$cpp"
