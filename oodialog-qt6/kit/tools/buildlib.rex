#!/usr/bin/env rexx
/* buildlib.rex -- build the renderer library (lib/liboodqt.so) for this computer from the kit's source.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-23.
 *
 *   rexx tools/buildlib.rex
 *
 * Needed only when tools/kitcheck.rex says the shipped library cannot load (an older or different
 * Qt, C library or C++ library).  Needs cmake, a C++17 compiler, and the Qt 6 development files for
 * Widgets and PrintSupport:
 *   Debian/Ubuntu:  sudo apt install cmake g++ qt6-base-dev
 *   Fedora:         sudo dnf install cmake gcc-c++ qt6-qtbase-devel
 *   openSUSE:       sudo zypper install cmake gcc-c++ qt6-base-devel qt6-printsupport-devel
 * The shipped library is kept as lib/liboodqt.so.shipped.
 */
trace off                               -- failing commands are reported, not traced
kit = filespec("location", .context~package~name)~strip("T", "/")
kit = kit~left(kit~lastPos("/") - 1)
progress = .ToolProgress~new("buildlib", .context~package, "RUN")
log = progress~logger
missing = .array~new
do tool over .array~of("cmake", "c++")
  address system 'command -v' tool '> /dev/null 2>&1'
  if rc \= 0 then missing~append(tool)
end
if missing~items > 0 then do
  log~log(.Log~ERROR, "not found:" missing~makeString("L", " ") "- install the packages named at the top of tools/buildlib.rex")
  exit 1
end
build = kit"/build-lib"
-- ooRexx's headers and libraries: under the prefix of the rexx that runs this (PREFIX/bin/rexx)
address system 'command -v rexx > "'build'.which" 2>/dev/null'
s = .stream~new(build".which"); rexxBin = s~lineIn~strip; s~close
call sysFileDelete build".which"
address system 'readlink -f "'rexxBin'" > "'build'.which"'
s = .stream~new(build".which"); rexxBin = s~lineIn~strip; s~close
call sysFileDelete build".which"
prefix = filespec("location", rexxBin)~strip("T", "/")
prefix = prefix~left(prefix~lastPos("/") - 1)
if \sysFileExists(prefix"/include/oorexxapi.h") & \sysFileExists(prefix"/include/ooRexx/oorexxapi.h") then do
  log~log(.Log~ERROR, "ooRexx's headers (oorexxapi.h) are not under" prefix"/include: install ooRexx's development files, or build ooRexx from source")
  exit 1
end
log~log(.Log~INFO, "ooRexx at" prefix)
log~log(.Log~INFO, "configuring" kit"/renderer-src into" build)
address system 'cmake -S "'kit'/renderer-src" -B "'build'" -DCMAKE_BUILD_TYPE=Release -DOOREXX_PREFIX="'prefix'" > "'build'.log" 2>&1'
if rc \= 0 then do
  log~log(.Log~ERROR, "cmake could not configure (Qt 6 Widgets and PrintSupport development files missing?): see" build".log")
  exit 1
end
log~log(.Log~INFO, "compiling (a minute or two)")
address system 'cmake --build "'build'" -j 4 >> "'build'.log" 2>&1'
if rc \= 0 then do
  log~log(.Log~ERROR, "the build failed: see" build".log")
  exit 1
end
lib = kit"/lib/liboodqt.so"
if sysFileExists(lib) & \sysFileExists(lib".shipped") then address system 'mv "'lib'" "'lib'.shipped"'
address system 'cp "'build'/liboodqt.so" "'lib'"'
log~log(.Log~INFO, "built" lib "- now: rexx tools/kitcheck.rex")
exit 0

::requires "../packages/oorexx_logging_stream_target_v0.1/src/LogStreamTarget.cls"
