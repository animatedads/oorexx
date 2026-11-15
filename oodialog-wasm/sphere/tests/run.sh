#!/bin/sh
# oodialog-wasm sphere: activation test through LLM Gopher.
# Use: GOPHER=/path/to/gopher SPHERE_ZIP=/path/to/packaged-sphere.zip sh tests/run.sh
set -eu
: "${GOPHER:?set GOPHER to the LLM Gopher v0.21-dev1+ launcher}"
: "${SPHERE_ZIP:?set SPHERE_ZIP to the packaged oodialog-wasm sphere}"
TMP=${TMPDIR:-/tmp}/oodialog-wasm-sphere-test.$$
ENVROOT="$TMP/env"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

"$GOPHER" sphere resolve oodialog-wasm --override "$SPHERE_ZIP" > "$TMP/resolve.json"
grep -q '"sphere": "oodialog-wasm"' "$TMP/resolve.json"

"$GOPHER" sphere load oodialog-wasm --override "$SPHERE_ZIP" --env "$ENVROOT" > "$TMP/load.json"
export LLM_GOPHER_ENV="$ENVROOT"

"$GOPHER" --profile oodialog-wasm context oodialog-wasm --full > "$TMP/context.json"
for id in ops.oodialog-wasm.start ops.oodialog-wasm.build-and-test ref.oodialog-wasm.renderer-contract \
          ref.oodialog-wasm.seams ops.oodialog-wasm.differences ref.oodialog-wasm.harness \
          ops.oodialog-wasm.port-a-native ref.oodialog-wasm.state ops.oodialog-wasm.lessons
do
  grep -q "$id" "$TMP/context.json"
done

"$GOPHER" --profile oodialog-wasm search resourceProvider --sphere oodialog-wasm > "$TMP/seam.json"
grep -q 'ref.oodialog-wasm.seams' "$TMP/seam.json"

"$GOPHER" --profile oodialog-wasm search msSleep --sphere oodialog-wasm > "$TMP/sleep.json"
grep -q 'ops.oodialog-wasm.differences' "$TMP/sleep.json"

"$GOPHER" --profile oodialog-wasm search 'separator character' --sphere oodialog-wasm > "$TMP/sep.json"
grep -q 'ref.oodialog-wasm.renderer-contract' "$TMP/sep.json"

echo 'PASS OODIALOG-WASM GOPHER SPHERE v0.1'
