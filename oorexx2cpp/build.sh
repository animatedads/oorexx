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
if grep -q rx_host_tier "$cpp"; then   # hosted tier: classes loaded from an embedded interpreter session
    : "${OO_ROOT:?OO_ROOT (ooRexx install with include/ and lib/) is required for hosted-tier classes}"
    echo "rx2cpp: hosted tier: $(grep -m1 RX2CPP_HOSTED "$cpp" | sed 's|^// RX2CPP_HOSTED:||') -- binary links librexx" >&2
    extra+=( -I"$OO_ROOT/include" -L"$OO_ROOT/lib" -Wl,-rpath,"$OO_ROOT/lib" -lrexx -lrexxapi )
fi
if [[ -n "${RX2CPP_LIBRARY:-}" ]]; then   # RX2CPP_LIBRARY=NAME: libNAME.so (classes + routines) via the one native-package lane
    exec "$ROOT/native/build.sh" "$input" "$(dirname -- "$native")" "$RX2CPP_LIBRARY"
fi
if [[ -n "${RX2CPP_KERNEL:-}" ]]; then   # RX2CPP_KERNEL=<kernel_spike work dir>: BIFs run in the compiled-in ooRexx kernel
    K=$RX2CPP_KERNEL; [[ -f "$K/b/lib/librexx.a" ]] || { echo "rx2cpp: no kernel in $K (run experiments/kernel_spike/build.sh)" >&2; exit 65; }
    FL="$K/b/CMakeFiles/rexx.dir/flags.make"
    KINC=$(grep CXX_INCLUDES "$FL" | sed 's/CXX_INCLUDES = //'); KDEF=$(grep CXX_DEFINES "$FL" | sed 's/CXX_DEFINES = //')
    kobj="$(dirname -- "$native")/$(basename -- "$native").kernel.o"
    # shellcheck disable=SC2086
    "${CXX:-g++}" -std=gnu++11 -O2 -fno-lifetime-dse $KDEF $KINC -I"$K/src/interpreter/api" -I"$K/b" -I"$ROOT/kernel" -c "$ROOT/kernel/rx_kernel_bif.cpp" -o "$kobj"
    extra+=( -DRX2CPP_KERNEL -I"$ROOT/kernel" "$kobj" "$K/b/lib/librexx.a" "$K/b/lib/librexxapi.a" -lpthread -ldl )
    cp "$K/b/lib/rexx.img" "$(dirname -- "$native")/rexx.img"   # the kernel restores this image at start-up (found beside the executable)
fi
if [[ -n "${RX2CPP_KERNEL:-}" ]]; then
    # strict warnings for the generated program; the kernel's own link-time warnings are not ours to fail on
    gobj="$(dirname -- "$native")/$(basename -- "$native").gen.o"
    cflags=( ); sources=( )
    for item in "${extra[@]}"; do
        case "$item" in -I*|-D*) cflags+=( "$item" );; esac
    done
    "${CXX:-g++}" -std=c++17 -O2 -Wall -Wextra -Werror -I"$ROOT/include" "${cflags[@]}" -c "$cpp" -o "$gobj"
    "${CXX:-g++}" -std=c++17 -O2 -w -I"$ROOT/include" "$gobj" "${extra[@]}" -o "$native"
else
    "${CXX:-g++}" -std=c++17 -O2 -Wall -Wextra -Werror -I"$ROOT/include" "$cpp" "${extra[@]}" -o "$native"
fi
printf 'Native executable: %s (generated C++: %s)\n' "$native" "$cpp"
