**Native BIF v0.15 — block-qualified native semantics.** See `README_V015.md` and `QUALIFICATION_V015.md`.

**Current add-on: v0.14; see README_V014.md and QUALIFICATION_V014.md.**

# Current add-on: v0.12 control-state activation

See `README_V012.md`, `control/CONTROL_CONTRACT.md`, and `QUALIFICATION_V012.md`. This is independent of rx2cpp, which is not modified.

---

## v0.11 variable-activation BIF coverage

See [README_V011.md](README_V011.md), [variables/VARIABLE_CONTRACT.md](variables/VARIABLE_CONTRACT.md) and [QUALIFICATION_V011.md](QUALIFICATION_V011.md). Standalone add-on only, no rx2cpp modification.

---

## v0.10 compiled-frame BIF adapters (ARG and ADDRESS)

See [README_V010.md](README_V010.md), [frame/FRAME_CONTRACT.md](frame/FRAME_CONTRACT.md), and [QUALIFICATION_V010.md](QUALIFICATION_V010.md). The BIF add-on remains separate from rx2cpp.

---

# v0.9 — BIF native fallback safety and rx2cpp v0.25 compatibility

**New:** `rxbif::NativeSubsetUnsupported` is the *only* exception which
permits native-to-ooRexx retry. Arbitrary C++/call errors no longer produce a
second invocation. `NUMERIC DIGITS/FUZZ/FORM` must still be read for each
actual pass-through. The compiler is neither amended nor implicitly integrated.

See `README_V09.md`, `V025_COMPATIBILITY.md`, `QUALIFICATION_V09.md`.

---

# rx2cpp BIF source rules v0.8 — current numeric context per delegation

This is an independent add-on: rx2cpp compiler v0.23 source is untouched.

**Change:** `rxbif_breadth::Context` now accepts `NumericSupplier currentNumeric`,
a callable that reads the active NUMERIC DIGITS/FUZZ/FORM **immediately before
EVERY fallback**. The new supplier takes precedence over the older `numeric`
snapshot. The older snapshot parameter remains for single-invocation or
provably immutable contexts only; it must not be reused across changes to
`NUMERIC` instructions, nested activations, or unrelated callers.

The live same-instance `rxbif_live::CallScope` binds a NumericSupplier to its
borrowed `RexxCallContext`. That value is checked against the current live
activation before executing a permitted BIF. The exact captured snapshot is
passed to `execute`, which installs the numeric prologue only inside the
subordinate BIF routine. No stale constructor-time `CallScope` snapshot is
used; the calling activation is not changed. The interface remains limited
to admitted scalar results and does **not** conjure ARG/TRACE/ADDRESS frame
state or permit unrelated stream/queue operations.

The ooRexx-written `BifSourceReader.cls` now masks C++ comments and ordinary
quoted strings across source lines before discovering `BUILTIN(NAME)` and its
Min/Max declarations. This also protects brace balancing from quoted or
commented braces. An adversarial fixture containing false declarations and
macros in both kinds of comments and in strings must yield exactly one real
REVERSE rule. The original upstream body remains intact for downstream
conversion rules; only lexical analysis is masked.

Example C++ for a mutable compiled activation (caller owns lifetime):

```cpp
rxbif_breadth::Context bridge(native,
    [&](const std::string& name, const std::vector<rxbif_breadth::Slot>& args,
        const rxbif_breadth::NumericContext& liveNumerics) -> rx::Value {
        return hostExecuteInCallerActivation(name, args, liveNumerics);
    }, std::nullopt,
    [&]() -> rxbif_breadth::NumericContext {
        // Read real current activation fields here, not constructor defaults.
        return {frame.digits(), frame.fuzz(), frame.isEngineering()
            ? rxbif_breadth::NumericForm::Engineering
            : rxbif_breadth::NumericForm::Scientific};
    });
```

The example's `hostExecuteInCallerActivation` is an integration callback,
**not** a shipped implementation of an arbitrary activation-dependent BIF.
A missing supplier/snapshot or invalid NUMERIC state fails before delegation.

Run on staged ooRexx and unchanged rx2cpp v0.23:

```sh
export RX2CPP_BASE=/path/to/rx2cpp_oorexx_v0.23
export OO_ROOT=/path/to/oorexx/usr/local
export REXX_BIN="$OO_ROOT/bin/rexx"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
./tests/run.sh
./tests/run_breadth.sh
./live/tests/run.sh
CXX=clang++ BUILD_DIR=/tmp/bif_clang_native ./tests/run.sh
CXX=clang++ BUILD_DIR=/tmp/bif_clang_breadth ./tests/run_breadth.sh
CXX=clang++ BUILD_DIR=/tmp/bif_clang_live ./live/tests/run.sh
```

See `QUALIFICATION_V08.md` and `NUMERIC_CONTEXT_CONTRACT_V08.md`.
The 81-name catalogue is routing coverage, **not** 81 full semantic
implementations. The complete original `BuiltinFunctions.cpp` still needs to
be supplied to qualify non-synthetic full-source 81-rule generation.

---

# rx2cpp BIF source rules v0.7 — numeric-context-preserving pass-through

**BIF-only add-on**. The original rx2cpp compiler/repository is **unchanged**.
This package continues the ooRexx-written source-rule generation and 81-name
routing catalogue from v0.5, plus the v0.6 live-activation bridge.

**Change required by the Architect:** EVERY invocation that leaves native code
for ooRexx (either a new isolated interpreter or a callback into an existing
instance) must transport the **caller's** NUMERIC DIGITS, FUZZ and FORM. Never
use the callee's defaults silently. Numerical execution MUST be equivalent
only within the other documented limitations of the bridge.

The add-on now uses `rxbif_breadth::NumericContext`:

```cpp
struct NumericContext {
    std::size_t digits;
    std::size_t fuzz;
    NumericForm form; // Scientific or Engineering
};
```

`rxbif_breadth::Context::numeric` is an optional numeric snapshot. It is
**mandatory** for any `Context::chainback` execution, even when the target BIF
is normally native but its particular arguments fall outside the native subset.
Handlers now receive `(name, vector<Slot>, const NumericContext&)`. Leaving the
snapshot unset causes an explicit exception BEFORE any delegate is called.

The detached interpreter API has changed to
`IsolatedOoRexx::call(name, slots, callerNumeric)`. It applies the three Rexx
`NUMERIC` directives in its invoked activation before calling the whitelisted
BIF, including omitted positional arguments. A fresh default numeric context
is **not** an admissible substitute for the real caller snapshot.

`rxbif_live::CallScope` samples the actual borrowed `RexxCallContext` getters
at invocation, checks the interpreter/thread identity, validates that the
snapshot remains unchanged during dispatch, and applies the snapshot inside
Rexx routines created for `FORMAT`, `TRUNC`, `MAX`, `MIN`, `SIGN` and the other
catalogued isolated-safe BIFs. It preserves caller state because the numeric
prologue executes only within the newly invoked routine activation. It never
uses the misleading `SendMessage("FORMAT")` shortcut.

The new `BIF_LIVE_ARGS(name, arg1, ...)` export is a test/integration interface
for scalar built-ins. Values travel in ooRexx arrays and are never interpolated
into generated Rexx source; omission is maintained. BIFs requiring caller
frame/variables/streams/condition handling (`ARG`, `TRACE`, `ADDRESS`, `VALUE`,
stream and queue functions, etc.) still reject without their real adapter.
Native object marshalling and arbitrary Rexx numeric objects are not claimed.

The ooRexx `BifBreadthEmitter.cls` produces `requiresNumericContext` for **all
81 source-generated rule classes** (all can encounter the pass-through route).

See `NUMERIC_CONTEXT_CONTRACT.md` and `QUALIFICATION_V07.md` for qualification,
provisioning and compatibility details.

---

# rx2cpp BIF source rules v0.5 — breadth-first, explicit chainback

**New:** [COVERAGE_BREADTH_V05.md](COVERAGE_BREADTH_V05.md) documents the 81-name upstream BIF inventory, the separate ooRexx-written `bif2breadth.rex` rules generator, two callable C++ chain-back boundaries, and honest coverage limitations. It does **not** edit rx2cpp.

**Read-first:** 36 native-subset names + 2 existing rx2cpp names + 16 isolated-safe interpreter-mode names + 27 host-activation-required names. Names routable in a catalog are NOT synonymous with complete implementations: the 27 host-required names cannot execute until the host explicitly supplies an activation-preserving callback. The 16 isolated-mode names run in real ooRexx but with a fresh interpreter activation.

Smoke test (from add-on root, with rx2cpp v0.20 and ooRexx installed):

```sh
RX2CPP_BASE=/path/rx2cpp_oorexx_v0.20 OO_ROOT=/path/oorexx/usr/local ./tests/run_breadth.sh
```

Use the real full upstream `BuiltinFunctions.cpp` for source-derived 81-rule generation. Bundled full-name synthetic fixtures are **arity-only test data**.

---

# rx2cpp BIF source-rules pack v0.4 — DATE/TIME refinement

**This remains a standalone ooRexx-written conversion add-on; rx2cpp was not edited.**

See [CLOCK_SEMANTICS.md](CLOCK_SEMANTICS.md) and [QUALIFICATION_V04.md](QUALIFICATION_V04.md) for the v0.4 change, validation and remaining restrictions. The new DATE/TIME coverage includes base-date, base-microseconds, Unix civil ticks, ISO and national date variants, separators, civil/long time, timezone offset and elapsed/reset handling. The offline fixture includes upstream TIME but not the full DATE block; use upstream `BuiltinFunctions.cpp` to generate DATE's rule.

# Historical v0.1 documentation

**An independent add-on. Nothing in rx2cpp has been edited.**

The converter **is written in ooRexx** (`bif2inline.rex` plus `compiler/*.cls` and `rules/*.cls`). It consumes the real C++ source file `interpreter/expression/BuiltinFunctions.cpp` from ooRexx and constructs a small, source-traceable BIF intermediary. For each admitted function it writes:

* `Bif_NAME.cls` – **a separately loadable ooRexx rule class**, not a static hand-written registry entry. Provides source-derived name, arity, argument bindings, conversion kind and a C++ call-expression emitter.
* `rxbif.ir.tsv` – `RBI1` intermediary: source BIF name, arity, conversion kind (`METHOD` or `CLOCK_SUBSET`), original C++ delegate method, typed source arguments and source line.
* `rxbif_generated.hpp` – C++17 **inline call-site functions** with explicit source arity guards. In v0.4 nine BIFs have **fully inline native bodies** written by the ooRexx `BifInlineBackendRule.cls`; other admitted functions use named native helpers in `native/rxbif.cpp`. These helpers are native C++ and **do not link or invoke the ooRexx interpreter**.
* `coverage.tsv` – admissions and explicit rejections. A missing/changed method, dynamic arity, unsupported source body or absent native implementation is not considered an accepted translation.

The conversion is **not** a general C++ compiler or a mechanical copy of `BuiltinFunctions.cpp`. ooRexx built-ins depend heavily on interpreter objects (`RexxString`, activation, numeric contexts, symbols and error conditions). This version extracts the original BIF *front-door semantics* and only lowers operations for which a separate native subset has been implemented and tested. Do not treat a generated wrapper as proof of complete ooRexx equivalence.

## How to run on the actual ooRexx C++ source

The upstream source file is **an input, not edited or reconstructed by this package**. Clone/check out the ooRexx source you qualify against (prefer an exact revision), and run:

```sh
cd rx2cpp_bif_source_rules_v0.1
mkdir -p generated
rexx bif2inline.rex /path/to/ooRexx/interpreter/expression/BuiltinFunctions.cpp generated
```

The shipped `fixtures/BuiltinFunctions.excerpt.cpp` is a **verbatim small excerpt** for offline tests, including an entire `BUILTIN(TIME)` definition but not `BUILTIN(DATE)`; it is not the full ooRexx source file. Its generated results are included in `sample_generated/` to illustrate the exact `.cls` and native output. Use the complete official file for the full source inventory and rule regeneration.

## Native build and qualification

This pack expects the **unmodified** rx2cpp v0.20 `include/minirexx_runtime.hpp` for its `rx::Value` ABI. It does not import or redistribute rx2cpp code. Point at an existing extracted v0.20 release:

```sh
export RX2CPP_BASE=/path/to/extracted/rx2cpp_oorexx_v0.20
export REXX_BIN=/path/to/ooRexx/bin/rexx
export LD_LIBRARY_PATH=/path/to/ooRexx/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
./tests/run.sh
CXX=clang++ BUILD_DIR="$PWD/tests/_clang" ./tests/run.sh
```

The tested reference is ooRexx **5.3.0 r13196**, supplied as an Ubuntu debug `.deb` by the user. The interpreter may be staged under a custom prefix; do not assume `/usr/local`. The `.deb` contains binaries, *not the full interpreter C++ source*.

## Architecture and extension

1. `BifSourceReader.cls` locates real `BUILTIN(NAME)` blocks, balances C++ braces while ignoring strings/comments, and extracts upstream arity declarations even when immediately preceding the definition (`RIGHT`).
2. `BifMethodRule.cls` accepts only a constrained canonical forwarding wrapper; extracts `required_`/`optional_` C++ argument macros and the delegated method. It rejects extra statements and changed methods.
3. `BifClockRule.cls` treats `DATE`/`TIME` differently because they require activation-local clock state, elapsed-time state, calendar parsing and timezone logic. Its native support is a **restricted subset**.
4. `BifNativeCatalog.cls` cross-checks the qualified native set, signatures and exact upstream target method. It does not silently assume any unfamiliar C++ API means a supported implementation.
5. `BifInlineBackendRule.cls` chooses strictly verified direct-inline C++ expansions for `REVERSE` and `WORDS`; other admitted entries are still generated as inline wrappers around `rxbif::invoke`. `BifEmitter.cls` writes the IR, generated `.cls` classes, and C++ header, all **from ooRexx**.

The previously inspected rx2cpp built-in registry included `ABS` and `LENGTH`; this independent package does not replace them. Those two functions are **not replaced** here. The source-to-rule pipeline and native code are delivered for the rx2cpp maintainer to adopt; **no automatic integration or discovery by the unchanged rx2cpp executable is claimed**.

## What remains incomplete

The native pack includes qualified **subsets** for more than 31 BIF names, including: `ABBREV C2X CENTER CENTRE CHANGESTR COMPARE COPIES COUNTSTR DATE DELSTR DELWORD INSERT LASTPOS LEFT LOWER OVERLAY POS REVERSE RIGHT SPACE STRIP SUBSTR SUBWORD TIME UPPER WORD WORDINDEX WORDLENGTH WORDPOS WORDS X2C`. Some arguments, date formats and object coercions are deliberately rejected at runtime. See `QUALIFICATION.md`; these names are not equivalent to complete ooRexx functions. For DATE/TIME v0.4 coverage and remaining restrictions, see `CLOCK_SEMANTICS.md`.

The remaining ooRexx BIFs (including activation/stream/security/context-oriented functions and arbitrary object dispatch) remain unimplemented and will appear as `REJECTED` in the conversion inventory when the full upstream C++ input is used. Source code derived solely from a forwarded RexxString method is insufficient to prove its complete semantics; deeper source rules against `StringClass.cpp` / `RexxDateTime.cpp` are a future stage.

## Inputs and ownership

* Latest inspected base: `rx2cpp_oorexx_v0.20_delivery.zip`, used READ-ONLY for its native `rx::Value` ABI. **Never changed**.
* Source semantics: [`ooRexx/ooRexx/interpreter/expression/BuiltinFunctions.cpp`](https://github.com/ooRexx/ooRexx/blob/master/interpreter/expression/BuiltinFunctions.cpp), inspected Git blob `05ea58114e9e5b59a1cceebf8dd418b78058d342`. The source may evolve; prefer a pinned commit and rerun the converter.
* Native clock dependencies also inspected in upstream `RexxDateTime.cpp`; date and time are governed by activation-local clock state, not arbitrary wall-clock reads inside each BIF call.
* `fixtures/BuiltinFunctions.excerpt.cpp` contains extracts from ooRexx upstream, subject to its Common Public License 1.0. Attribution and license notice are in `UPSTREAM-NOTICE.txt`. This add-on's original code is MIT licensed (`LICENSE-ADDON.txt`); no ooRexx code is copied into the native runtime implementation.


## v0.14 — v0.28.1 thread-scoped BIF activation

See `activation/ACTIVATION_V0281_CONTRACT.md` for the separate optional RAII caller-binding bridge, concurrent-use rejection, and the non-integrated compiler boundary. All v0.13 implementation files remain unchanged.
