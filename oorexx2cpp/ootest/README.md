# v0.11 update

The new compound-assignment syntax is no longer a negative `+=` test.
Four differential cases exercise the independently loadable `+=`, `-=`, `*=`,
`/=` rule and operator dispatch. Negative controls cover `//=`, `%=`,
`**=`, `|=` and existing unsupported features. The completed v0.11 ooTest
adaptor checks **25 tests / 203 assertions** with each of GCC and Clang,
zero failures/errors. Exact historical-to-microcase scope is in
`assignment-coverage.tsv`. The v0.10 explanation below describes the
original integration and is retained for context; its test counts are
historical.

---

# ooTest integration for rx2cpp v0.10

This is an **ooRexx-written ooTest conformance adaptor**. `RX2CPP.testGroup`
executes using the upstream ooTest driver; the upstream snapshot supplies the
framework but is not bundled here. `OoTestGroupScanner.cls` and `inventory.rex`
produce a source-only corpus index. Interpreter samples are independently run,
compiled to native C++ by **rx2cpp**, then byte-compared by ooTest (stdout and
numeric process exit code); unsupported source must be rejected without
partial code generation.

Requirements: ooRexx runtime with `rexx`, `rxregexp.cls` and matching libraries;
C++17 compiler; upstream ooTest-4.2.0-snapshot06 unpacked; the same interpreter's
installed `HelloWorld.rex` sample. No package manager or system-wide ooRexx
installation is required. In particular the runtime may be staged in an
arbitrary root, as with Android/Termux. For the supplied standalone Linux
`.deb`, extract the package first and specify the installed root explicitly.

```sh
unzip ooTest-4.2.0-snapshot06.zip -d /tmp/ootest
export OO_TEST_ROOT=/tmp/ootest/ooTest-4.2.0-snapshot06
export OO_ROOT=/path/to/staged/usr/local
export REXX_BIN="$OO_ROOT/bin/rexx"
export REXX_LIB="$OO_ROOT/lib"
export OO_SAMPLES="$OO_ROOT/share/ooRexx/samples"

./ootest/inventory.sh
./ootest/reference-smoke.sh
./ootest/run.sh
```

## Exactly what is tested

The ooTest framework runner discovers `ootest/RX2CPP.testGroup` via `-R` and
`-f RX2CPP`. The run wrapper prebuilds **eight known-admitted script fixtures**
(the HelloWorld fixture comes from the ooRexx installation), and **five
negative examples**; the testGroup checks exit codes, stdout, compile status,
absence of generated files on errors, and diagnostic existence. Two additional
source-level tests exercise reference interpreter comparison strictness and
`expectSyntax(40.3)` on `STREAM()` with no arguments. The framework may also
report its own inherited test methods. Output comparison is byte-for-byte, not
normalised, which is intentional for Rexx semantics.

Three of the negative probes are derived from the first blockers seen in the
selected historic groups: `+=` (Assignments), `NUMERIC DIGITS` (ABS), and
`ABBREV(...)` (ABBREV). These are **recorded unsupported features**, not
successful compilations. The `ABBREV` probe currently stops at its comma, so
that diagnostic alone does not prove the next failure mode.

`reference-smoke.sh` runs exactly three inspected upstream 4.2 test groups,
**Assignments**, **ABS**, and **ABBREV**, in the official driver. These are
interpreter-side discovery checks only; they do not exercise compiled output.
No other upstream groups are executed automatically. The inventory scans
*.testGroup source without running it.

**WARNING:** ooTest 4.2.0 snapshot06 explicitly requires an ooRexx 4.2.0
interpreter for its official certification work. Our installed reference is a
5.3.0 internal test build. The *selected* 4.2 groups happen to run on 5.3,
but passing does not imply compatibility, full-suite qualification, or 5.3
coverage certification. The PDF at oorexx.org/docs/pdf/ootest.pdf describes
the newer **5.0** ooTest framework; it is not the version of the supplied zip.

The inventory feature counters are raw source-line **heuristics**, not parsed
Rexx grammar, methods successfully compiled, unique features, or percentages
of compiler conformance. The test method counter is likewise best effort.

## Handling failure

The historical ooTest driver can return process status 0 even when assertions
fail. `run.sh` and `reference-smoke.sh` fail closed by independently checking
`Failures: 0` and `Errors: 0` in the driver report. Negative-source tests
require that compilation fails and emits no C++ output. An intentionally
corrupted native-output file was verified to produce an ooTest failure.

## Next language modules suggested by the corpus

- `::method` bodies and general message sends, including `.Object` semantics,
  and `USE ARG`/`EXPOSE` for object state.
- `NUMERIC DIGITS/FUZZ/FORM` and arbitrary precision decimal, rather than
  assuming host integer arithmetic is ooRexx arithmetic.
- `PARSE`, `SELECT/WHEN`, and general compound `DO` forms.
- Built-in function dispatch (e.g. `ABS` and `ABBREV`), for which native
  implementations or explicit interpreter proxies must be chosen per operation.
- Stems and collections; error/condition parity (`expectSyntax`) at compiled
  and interpreter-proxy boundaries.

Every rule belongs in its own loadable ooRexx class. The corpus should be
triaged by individual method/semantic feature, not by attempting to compile
whole framework testGroups as if they were independent Rexx scripts.
