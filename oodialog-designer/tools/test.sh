#!/bin/sh
# Run tests/run_all.rex with this machine's REXX_PATH (after tools/make.sh).
# A shell line only because REXX_PATH must be set before ooRexx starts.
cd "$(dirname "$0")/.."
export REXX_PATH="$PWD/src:$PWD/tests:$PWD/site${REXX_PATH:+:$REXX_PATH}"
PATH="${RT:-/home/claude/rt}/node_modules/.bin:$PATH"
exec rexx tests/run_all.rex "$PWD" "$@"
