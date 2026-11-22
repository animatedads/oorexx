#!/bin/sh
# Build the site with this machine's inputs.  Override any with the environment.
set -e
cd "$(dirname "$0")/.."
export REXX_PATH="$PWD/src:$PWD/tests:${ESTATE:-/home/claude/estate-pkgs}/nosqlserver_v0.92-dev1/src:${ESTATE:-/home/claude/estate-pkgs}/alchemy_objects_v0.8/src:${ESTATE:-/home/claude/estate-pkgs}/oorexx_crypto_v0.1/src${REXX_PATH:+:$REXX_PATH}"
PATH="${RT:-/home/claude/rt25}/node_modules/.bin:$PATH"
exec rexx tools/build.rex \
  "${RUNTIME:-/home/claude/dl/web/oorexxwasm-web-0.2.5}" \
  "${OOD_DIST:-/home/claude/src/oodwasm/oodialog-wasm/dist}" \
  "${OBJED:-/home/claude/oxe}" \
  "${PARSER:-/home/claude/dl/rexx-parser-20261115}" \
  "${ESTATE:-/home/claude/estate-pkgs}"
