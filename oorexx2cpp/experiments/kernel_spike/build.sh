#!/usr/bin/env bash
# Compile the REAL ooRexx kernel in as static libraries and call its String methods directly.
# usage: build.sh /path/to/oorexx-source /path/to/workdir
set -euo pipefail
SRC=${1:?ooRexx source tree}; W=${2:?work dir}; HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mkdir -p "$W"; rm -rf "$W/src" "$W/b"; cp -r "$SRC" "$W/src"
sed -i 's/add_library(rexx SHARED/add_library(rexx STATIC/; s/add_library(rexxapi SHARED/add_library(rexxapi STATIC/' "$W/src/CMakeLists.txt"
# the ncurses extension is not needed for the kernel: do not require curses headers just to configure
sed -i '/liborxncurses.so ####/{n;s/if (NOT WIN32)/if (FALSE)/}' "$W/src/CMakeLists.txt"
mkdir "$W/b"; ( cd "$W/b"; cmake ../src -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON >cfg.log
  make -j"$(nproc)" rexx rexxapi rexx_img rexx_exe >make.log )
FL="$W/b/CMakeFiles/rexx.dir/flags.make"
INC=$(grep CXX_INCLUDES "$FL" | sed 's/CXX_INCLUDES = //'); DEF=$(grep CXX_DEFINES "$FL" | sed 's/CXX_DEFINES = //')
g++ -std=gnu++11 -O1 -fno-lifetime-dse $DEF $INC -I"$W/src/interpreter/api" -I"$W/b" "$HERE/direct_call.cpp" \
    "$W/b/lib/librexx.a" "$W/b/lib/librexxapi.a" -lpthread -ldl -o "$W/direct_call"
g++ -std=gnu++11 -O1 -fno-lifetime-dse $DEF $INC -I"$W/src/interpreter/api" -I"$W/b" "$HERE/builtin_call.cpp" \
    "$W/b/lib/librexx.a" "$W/b/lib/librexxapi.a" -lpthread -ldl -o "$W/builtin_call"
g++ -std=gnu++11 -O1 -fno-lifetime-dse $DEF $INC -I"$W/src/interpreter/api" -I"$W/b" -I"$HERE" "$HERE/probe.cpp" \
    "$W/b/lib/librexx.a" "$W/b/lib/librexxapi.a" -lpthread -ldl -o "$W/probe"
cp "$W/b/lib/rexx.img" "$W/"    # the kernel restores this memory image at start-up; without it: SIGILL in Interpreter::logicError
( cd "$W" && ./direct_call && ./builtin_call )
# the compiled-in kernel as a complete interpreter (static, no librexx): this is "our compiled rexx"
( cd "$W/b/lib" && ../bin/rexx -v | head -2 )
