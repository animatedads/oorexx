#!/usr/bin/env bash
# Translation-only sweep over the ooRexx-installed sample corpus.
# No sample is executed: many prompt for input, modify files, or use networks.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SAMPLES=${OO_SAMPLES:-${OO_ROOT:-/usr/local}/share/ooRexx/samples}
OUT=${AUDIT_OUT:-$ROOT/build/sample-audit}
if [[ ! -d "$SAMPLES" ]]; then
  printf 'Cannot find samples directory: %s (set OO_SAMPLES)\n' "$SAMPLES" >&2
  exit 66
fi
mkdir -p "$OUT/diagnostics" "$OUT/translation-candidates"
manifest=$OUT/manifest.tsv
printf 'relative_source\tsha256\tstatus\tline_diagnostic\n' >"$manifest"
scanned=0; candidates=0; rejected=0; errors=0
while IFS= read -r -d '' source; do
  rel=${source#"$SAMPLES"/}
  name=${rel//\//__}
  digest=$(sha256sum "$source" | cut -d' ' -f1)
  output=$OUT/translation-candidates/$name.cpp
  diagnostic=$OUT/diagnostics/$name.log
  rm -f "$output"
  if timeout "${AUDIT_TIMEOUT:-15}" "$ROOT/run-compiler.sh" "$source" "$output" >"$diagnostic" 2>&1; then
    if [[ -s "$output" ]]; then
      state='CANDIDATE_UNVERIFIED'; candidates=$((candidates + 1))
    else
      state='ERROR_NO_OUTPUT'; errors=$((errors + 1))
    fi
  else
    status=$?
    if [[ $status -eq 65 ]]; then state='UNSUPPORTED'; rejected=$((rejected + 1))
    elif [[ $status -eq 124 ]]; then state='TIMEOUT'; errors=$((errors + 1))
    else state='COMPILER_ERROR'; errors=$((errors + 1))
    fi
  fi
  first=$(head -n 1 "$diagnostic" | tr '\t\r\n' '   ')
  first=${first//"$SAMPLES"/samples}
  printf '%s\t%s\t%s\t%s\n' "$rel" "$digest" "$state" "$first" >>"$manifest"
  scanned=$((scanned + 1))
done < <(find "$SAMPLES" -type f \( -iname '*.rex' -o -iname '*.cls' \) -print0 | sort -z)
printf 'SAMPLE AUDIT: scanned=%d candidates(unverified)=%d unsupported=%d errors=%d\n' \
    "$scanned" "$candidates" "$rejected" "$errors"
printf 'Manifest: %s\n' "$manifest"
# No false semantic claims: a translation candidate is not a passing sample.
