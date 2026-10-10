#!/usr/bin/env bash
# Safe, translation-only inventory of shipped ooRexx class-file candidates.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_SAMPLES=${OO_SAMPLES:-${OO_ROOT:-/usr/local}/share/ooRexx/samples}
AUDIT_OUT=${AUDIT_OUT:-$ROOT/build/hybrid-class-audit}
[[ -d "$OO_SAMPLES" ]] || { echo "Missing ooRexx examples: $OO_SAMPLES" >&2; exit 66; }
mkdir -p "$AUDIT_OUT"
manifest="$AUDIT_OUT/manifest.tsv"
printf 'path\tsha256\tresult\tfirst_diagnostic\n' >"$manifest"
while IFS= read -r -d '' source; do
    rel=${source#"$OO_SAMPLES"/}
    hash=$(sha256sum "$source" | cut -d' ' -f1)
    prefix="$AUDIT_OUT/candidate"
    rm -f "$prefix.cpp" "$prefix.hpp" "${prefix}_proxy.rex"
    if "$ROOT/run-hybrid-compiler.sh" "$source" "$prefix" >"$AUDIT_OUT/compile.log" 2>&1; then
        result=compiled
        reason=-
    else
        result=rejected
        reason=$(tr '\t\n\r' '   ' <"$AUDIT_OUT/compile.log" | cut -c1-200)
    fi
    printf '%s\t%s\t%s\t%s\n' "$rel" "$hash" "$result" "$reason" >>"$manifest"
done < <(find "$OO_SAMPLES" -type f -iname '*.cls' -print0 | sort -z)
rm -f "$AUDIT_OUT/candidate.cpp" "$AUDIT_OUT/candidate.hpp" "$AUDIT_OUT/candidate_proxy.rex" "$AUDIT_OUT/compile.log"
cat "$manifest"
