#!/bin/sh
set -eu
: "${OO_ROOT:?Set OO_ROOT to extracted ooRexx usr/local root}"
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$HERE:$OO_ROOT/bin${REXX_PATH:+:$REXX_PATH}"
"$OO_ROOT/bin/rexx" "$HERE/tests/smoke.rex"
"$OO_ROOT/bin/rexx" "$HERE/tests/model.rex"
"$OO_ROOT/bin/rexx" "$HERE/tests/extended.rex"
"$OO_ROOT/bin/rexx" "$HERE/tests/resource_model.rex"
(cd "$HERE" && "$OO_ROOT/bin/rexx" "$HERE/tests/rc_v5.rex")