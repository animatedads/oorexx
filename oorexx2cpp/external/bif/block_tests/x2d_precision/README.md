# X2D — independent precision expansion regression

Test-first supplement for GitHub `animatedads/oorexx`'s native `X2D` implementation.
It adds **no conversion implementation**, changes no compiler code, and does not
import historic native-BIF ZIP content. Qualification started from the exact Git
blob `6ecc1a2987889b850a86d4ddc82ddea3c9c4bee7` (native/rxbif_x2d.hpp).

The deterministic fixture produces 8,982 separate input/width combinations,
including grouped hexadecimal, malformed grouping, binary NUL/FF, signed
nibble widths, excessive lengths, noncanonical width strings and decimal
precision boundaries. The interpreter oracle runs each combination under
NUMERIC DIGITS **1, 3, 9, 34 and 64**. The C++17 runner calls the *actual*
`rxbif_x2d.hpp` from the current checked GitHub worktree, not a copied engine.

Run from a fresh repository checkout:

```sh
export RX2CPP_BASE=/checkout/animatedads/oorexx/oorexx2cpp
export OO_ROOT=/path/to/oorexx/usr/local
bash "$RX2CPP_BASE/external/bif/block_tests/x2d_precision/run_precision.sh"
```

The script requires a Git commit SHA and records it. Exact-value and
error-vs-value comparisons are made with the real interpreter. Under GCC and
Clang, each precision has 5,367 genuinely native comparisons with no
mismatch; the other 3,615 are **typed unqualified** cases for live-host
resolution and are not counted as passes. Total independently matched native
comparisons: **53,670**, with 36,150 typed deferrals across both compilers.
The classification counts are checked so that accidental native-coverage
expansion or contraction requires explicit test review.

**Limitations:** This test does not validate exact Rexx condition numbers,
noncanonical-width conversions by a hosted fallback, or a current-compiler
end-to-end compiled program. Those remain separately qualified boundaries.
The initial local run used a byte-for-byte reconstructed current GitHub X2D
header (the Git blob SHA was verified); a subsequent CI/current checkout run
should confirm the same result with this repo's native source. The ooRexx
reference interpreter was 5.3.0 r13196.
