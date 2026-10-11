#!/usr/bin/env bash
# Rebuild ONLY the probe from the kernel libraries that build.sh already made (takes about 1 minute, not 30).
# usage: rebuild_probe.sh WORKDIR     (WORKDIR = the one given to build.sh, for example /tmp/kernel_work)
set -euo pipefail
W=${1:?workdir}; HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ -f "$W/b/lib/librexx.a" ]] || { echo "no kernel in $W: run build.sh first"; exit 1; }
FL="$W/b/CMakeFiles/rexx.dir/flags.make"
INC=$(grep CXX_INCLUDES "$FL" | sed 's/CXX_INCLUDES = //'); DEF=$(grep CXX_DEFINES "$FL" | sed 's/CXX_DEFINES = //')
g++ -std=gnu++11 -O1 -fno-lifetime-dse $DEF $INC -I"$W/src/interpreter/api" -I"$W/b" -I"$HERE" "$HERE/probe.cpp" \
    "$W/b/lib/librexx.a" "$W/b/lib/librexxapi.a" -lpthread -ldl -o "$W/probe"
cp "$W/b/lib/rexx.img" "$W/"
echo "probe rebuilt: $W/probe"
