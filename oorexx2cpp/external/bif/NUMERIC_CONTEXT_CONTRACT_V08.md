# v0.8 dynamic activation NUMERIC context contract

- For every cross-boundary BIF execution, the initiating activation owns the
  NUMERIC DIGITS/FUZZ/FORM setting. Pass these exact three values, with no
  fabricated defaults, to the destination before the BIF executes.
- A mutable activation MUST install `currentNumeric` on
  `rxbif_breadth::Context`. This producer is sampled separately for each
  chain-back (including implicit fallback after a native-subset refusal).
  It must be synchronous and refer to the actual live caller frame.
- The old `numeric` optional snapshot remains an API compatibility feature for
  call-scoped or immutable producers only. Reusing it while `NUMERIC` settings
  can change is incorrect; the bridge cannot detect that misuse from the
  snapshot value alone. The new supplier overrides the old snapshot.
- Failure to obtain NUMERIC state, invalid values (`digits=0` or `fuzz>=digits`),
  or a live change between sampling and dispatch must fail closed.
- A same-instance `CallScope` uses a borrowed `RexxCallContext` as its
  authoritative snapshot source on every pass-through. The underlying
  interpreter instance pointer alone cannot reproduce the caller's NUMERIC
  context or execution frame.
- A nested chain-back receives its own context read. If an outer call's
  activation is restored afterward, subsequent calls observe restored state.
- Detached isolated ooRexx `IsolatedOoRexx::call(name, args, NumericContext)`
  takes a mandatory explicit snapshot for each invocation and reapplies it in
  a fresh activation. The called routine cannot silently inherit host defaults.
- This contract does not transport source lines, trap/condition state, argument
  list, variable dictionary, user-defined override visibility, stream registry,
  queues, native object identity or the entire call frame. Those remain
  separate required adapters and must not be approximated.
