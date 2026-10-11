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
if [[ -n "${RX2CPP_LIBRARY:-}" ]]; then   # RX2CPP_LIBRARY=NAME: build libNAME.so for ::requires "NAME" library
    : "${OO_ROOT:?OO_ROOT (ooRexx install with include/oorexxapi.h) is required for library mode}"
    names=$(grep -o '_rxRoutines\["[A-Z0-9_.!?]*"\] =' "$cpp" | sed 's/.*\["\(.*\)"\].*/\1/')
    {
        echo '#include "oorexxapi.h"'
        echo 'static void rxLibLoad(RexxThreadContext *) { rxLibMain(); }'
        echo 'static RexxObjectPtr rxLibCall(RexxCallContext *c, const char *n, RexxArrayObject a) {'
        echo '    std::vector<rx::Value> args; size_t cnt = a ? c->ArrayItems(a) : 0;'
        echo '    for (size_t i = 1; i <= cnt; i++) { RexxObjectPtr o = c->ArrayAt(a, i); args.push_back(rx::Value::string(o ? c->ObjectToStringValue(o) : "")); }'
        echo '    try { auto r = rxLibRoutines.at(n)(rxLibVars, args); return r ? (RexxObjectPtr)c->String(r->bytes.c_str(), r->bytes.size()) : NULLOBJECT; }'
        echo '    catch (const std::exception &e) { c->RaiseException1(Rexx_Error_Execution_user_defined, c->String(e.what())); return NULLOBJECT; } }'
        for n in $names; do
            printf 'RexxRoutine1(RexxObjectPtr, rxlib_%s, ARGLIST, args) { return rxLibCall(context, "%s", args); }\n' "${n//[^A-Za-z0-9_]/_}" "$n"
        done
        echo 'static RexxRoutineEntry rxLibRoutineTable[] = {'
        for n in $names; do
            printf '    REXX_TYPED_ROUTINE(%s, rxlib_%s),\n' "$n" "${n//[^A-Za-z0-9_]/_}"
        done
        echo '    REXX_LAST_ROUTINE() };'
        echo "static RexxPackageEntry ${RX2CPP_LIBRARY}_package_entry = { STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_0_0, \"${RX2CPP_LIBRARY}\", \"1.0\", rxLibLoad, NULL, rxLibRoutineTable, NULL };"
        echo "OOREXX_GET_PACKAGE(${RX2CPP_LIBRARY});"
    } >> "$cpp"
    libdir=$(dirname -- "$native")
    "${CXX:-g++}" -std=c++17 -O2 -fPIC -shared -w -I"$ROOT/include" -I"$OO_ROOT/include" "$cpp" "${extra[@]}" -o "$libdir/lib${RX2CPP_LIBRARY}.so"
    echo "rx2cpp: library: $libdir/lib${RX2CPP_LIBRARY}.so (use: ::requires \"${RX2CPP_LIBRARY}\" library)" >&2
    exit 0
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
