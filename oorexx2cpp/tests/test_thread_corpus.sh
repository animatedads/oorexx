#!/usr/bin/env bash
# Claude-provided ooRexx concurrency corpus. Independent language/runtime gate.
# Reference stage: interpreter stdout/exit code parity across repeated runs.
# Compiler stage: unsupported source must fail without clobbering output.
# An accepted source MUST receive an additional interpreted/native parity test.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
CORPUS="$ROOT/qualification/thread_corpus/thr_corpus"
REXX_BIN=${REXX_BIN:-rexx}
RUNS=${RUNS:-2}
MODE=${MODE:-all}
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
case "$RUNS" in *[!0-9]*|'') echo 'RUNS must be a positive integer' >&2; exit 2;; esac
if (( RUNS < 1 )); then echo 'RUNS must be a positive integer' >&2; exit 2; fi
if [[ "$MODE" == 'all' || "$MODE" == 'oracle' ]]; then
  bash "$CORPUS/run_corpus.sh" "$REXX_BIN" "$RUNS" check
fi
if [[ "$MODE" == 'all' || "$MODE" == 'compiler' ]]; then
  WORK=$(mktemp -d)
  trap 'rm -rf "$WORK"' EXIT
  printf 'test\tstatus\tcompiler_exit\n' > "$WORK/compiler_results.tsv"
  verified=0
  for f in "$CORPUS"/tests/*.rex; do
    name=$(basename "$f" .rex)
    target="$WORK/$name.cpp"
    printf '// SENTINEL: prior valid generated source\n' > "$target"
    if RX2CPP_HOSTED=0 "$ROOT/run-compiler.sh" "$f" "$target" > "$WORK/$name.log" 2>&1; then
      echo "NEEDS NATIVE QUALIFICATION: $name was accepted by the compiler" >&2
      # Do not silently claim threading correctness when compilation succeeds.
      exit 1
    else
      code=$?
      if [[ "$code" == 124 || "$code" == 137 ]]; then
        echo "Compiler timed out or was killed on $name: exit $code" >&2
        exit 1
      fi
    fi
    if [[ $(cat "$target") != '// SENTINEL: prior valid generated source' ]]; then
      echo "FAIL: $name overwrote existing generated source" >&2
      exit 1
    fi
    printf '%s\tREJECTED_SAFE\t%s\n' "$name" "$code" >> "$WORK/compiler_results.tsv"
    verified=$((verified + 1))
  done
  echo "Compiler fail-closed gate: $verified cases rejected without clobbering output"
fi
