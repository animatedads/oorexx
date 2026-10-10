# v0.8 qualification — 10 October 2026

Inputs:
- BIF v0.7 numeric-context pack, extended only in this add-on.
- Unchanged rx2cpp v0.23 native ABI headers (read-only).
- User-supplied ooRexx 5.3.0 r13196 interpreter binaries extracted from .deb.
- Upstream `BuiltinFunctions.cpp` still has a 12-definition genuine excerpt;
  the 81-name inventory fixture is synthetic and verifies routing metadata.

## Executed results

| Suite | GCC C++17 -O2 | Clang C++17 -O2 |
|---|---|---|
| `tests/run_breadth.sh` | PASS | PASS |
| `live/tests/run.sh` | PASS | PASS |
| `tests/run.sh` | PASS | PASS |
| Upstream excerpt rule generation | 12/12 | 12/12 |
| Full synthetic 81-name route generation | 81/81 | 81/81 |
| Real detached interpreter fallback cases | 17 PASS | 17 PASS |
| Existing native generated-header cases | 37 PASS | 37 PASS |
| General ooRexx/native differential microcases | 110 PASS | 110 PASS |
| DATE/TIME exact differential cases | 49 PASS in 5 timezones | 49 PASS in 5 timezones |
| DATE/TIME native clock contracts | 21 PASS | 21 PASS |

### New regression scenarios

1. One long-lived BIF bridge with mutable numeric supplier: settings
   9/0/SCIENTIFIC, 4/1/ENGINEERING, then 12/2/SCIENTIFIC read on three
   successive calls, ignoring deliberately stale initial snapshot.
2. Omitted argument in a native-subset BIF redirects via exactly the same
   current NUMERIC supplier.
3. Invalid live numeric settings and a throwing numeric supplier prevent
   callback execution; there is no fallback to stale defaults.
4. Nested invocation of a second delegated BIF captures changed NUMERIC
   settings independently, and restored settings remain visible outside.
5. Same-instance `CallScope` live tests maintain NUMERIC across FORMAT,
   TRUNC, MAX, SIGN under default/changed/nested activation settings.
6. C++ source-reader negative fixture includes fake BUILTIN names in multiline
   comments, line comments and strings; quoted/annotated arities cannot replace
   the genuine source definition.
7. Previously documented source drift, unknown BIF, missing live adapter,
   and illegal arity tests still reject.

## Honest limits

- **Routing coverage** is 81/81 names via explicit host callback; this does
  not confer complete support for 27 activation-dependent names absent their
  respective callbacks.
- Existing 38 native/base names are not fully semantically equivalent to
  ooRexx in all contexts. The full upstream ooTest corpus has not passed.
- Upstream `BuiltinFunctions.cpp` was not supplied as a complete pinned
  local C++ source file; a genuine 12-BIF excerpt and a synthetic 81-name
  fixture were tested. Full-file generation remains unqualified.
- The direct/isolated bridge scalar argument/result contract cannot preserve
  arbitrary Rexx object identity, methods or caller routine overrides.
- The static optional `numeric` parameter must be regarded as a single-call
  snapshot, not a dynamic activation reference. Use `currentNumeric` for
  mutable activations.
- rx2cpp v0.23 is untouched and has NOT automatically acquired these BIFs.
