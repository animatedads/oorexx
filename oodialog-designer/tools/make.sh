#!/bin/sh
# Build the site with this machine's inputs.  Override any with the environment.
set -e
cd "$(dirname "$0")/.."
export REXX_PATH="$PWD/src:$PWD/tests${REXX_PATH:+:$REXX_PATH}"
PATH="${RT:-/home/claude/rt}/node_modules/.bin:$PATH"
exec rexx tools/build.rex \
  "${RUNTIME:-/home/claude/dl/web/oorexxwasm-web-0.2.4}" \
  "${OOD_DIST:-/home/claude/src/oorexx/oodialog-wasm/dist}" \
  "${OBJED:-/home/claude/oxe}" \
  "${PARSER:-/home/claude/josepmariablasco/oorexxwasm/playground/rexx-parser}" \
  "${ESTATE:-/home/claude/estate-pkgs}"
