#!/usr/bin/env bash
# Supplier interpreter/native differential now includes:
# (1) dense Supplier NEW,
# (2) explicit Supplier NEW with sparse items AND indexes: missing positions => .NIL,
# (3) sparse Array~supplier, DO OVER, ALLINDEXES, ALLITEMS: holes skipped,
# (4) explicit Supplier NEW with sparse items, dense indexes: .NIL preserved.
# Shared driver verifies live interpreter oracle and byte-identical compiled output.
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec "$HERE/check_native_nine_one.sh" supplier
