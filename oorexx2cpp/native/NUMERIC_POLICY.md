# Native number policy — design checkpoint (not yet implemented)

The compiler should choose representation separately from ooRexx numeric
semantics. `int64_t` is a fast representation, **not** a replacement for the
active `NUMERIC DIGITS / FUZZ / FORM` context.

- **Proven-small exact integer:** Fast checked `int64_t` if inputs and outputs
  fit and the surrounding decimal numeric context guarantees identical Rexx
  rounding and formatting.
- **Large integer:** Promote to BigInt only if the value or operation actually
  requires more than 64-bit integer range. Static literals and compile-time
  propagation can establish some cases; dynamic operands need runtime guards.
- **Decimal/fraction/precision:** Use a decimal arithmetic engine with the
  active ooRexx numeric context. An arbitrary-precision *integer* cannot on
  its own reproduce decimal division, rounding, `NUMERIC FORM`, or `FUZZ`.
- **Unknown dynamic value:** Retain guarded integer fast paths with runtime
  promotion/deoptimisation, never overflow or change results silently.
- **Class and routine activations:** Save/restore numeric context as required
  by ooRexx's activation semantics; do not make process-global digit settings.

Reference probes against ooRexx 5.3:

    NUMERIC DIGITS 9
    say 999999999 + 1         -- 1.00000000E+9
    NUMERIC DIGITS 25
    say 9223372036854775807 + 1  -- 9223372036854775808

The present backend still has a deliberately restricted numeric subset. This
policy is not a claim that BigInt, arbitrary precision or numeric context
propagation have been implemented. `crypto.cls` must remain fail-closed until
those capabilities are qualified with ooTest and interpreter parity tests.
