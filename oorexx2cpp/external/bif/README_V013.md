# rx2cpp BIF v0.13 — v0.28 activation and typed-extlib interoperability

Stand-alone **BIF-only** add-on from v0.12, with the unchanged ooRexx BIF
source-reading conversion rules and native implementations retained.

New optional, separately compiled headers under `activation/`:

- `rxbif_v028_activation.hpp` — read `DIGITS`, `FUZZ` and `FORM` from the
  *current* v0.28 activation; reuse v0.28's own variable BIF provider;
  optionally delegate `ARG`, `ADDRESS`, `TRACE`, `SOURCELINE`, `CONDITION` to
  explicit, genuine caller-frame/control providers.
- `rxbif_v028_extlib.hpp` — bind external typed-routine host to the dynamic
  activation pool, preserving variable/stem distinction and refreshing all
  three numeric settings before each external routine call.
- `activation/tests` — GCC/Clang tests against exact user-supplied v0.28,
  external-library and ooRexx 5.3 dependencies.

The BIF converter is still written in ooRexx. The new C++ glue is a consumer
integration seam and does not pretend to convert original ooRexx BIF source.
No compiler files, external library files, or Claude patch changes are included.

Read `activation/ACTIVATION_V028_CONTRACT.md` and `QUALIFICATION_V013.md`
for reproducibility, qualification boundaries and integration requirements.
