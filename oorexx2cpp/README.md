## Getting started

Requirements:
- ooRexx 5.3 installed, with its headers (`include/oorexxapi.h`); `OO_ROOT` names its prefix (default `/usr/local`)
- a C++17 compiler: g++ 13 or clang++ (`CXX=` chooses; g++ by default)
- the Boost headers (Boost.Multiprecision, `boost/multiprecision/cpp_int.hpp`); on Debian / Ubuntu:

```
sudo apt install libboost-dev
```

Compile a whole program (its main code, routines and classes, and the `::REQUIRES` packages found next to it or on
`REXX_PATH`) into a native library and a launcher:

```
native/compile_program.sh prog.rex outdir
```

```
LD_LIBRARY_PATH=outdir rexx outdir/prog.rex
```

A `::REQUIRES` that is not compiled (not found, a `.rex` package, or kept with `RX2CPP_KEEP_INTERPRETED`) is loaded by
the interpreter at run time; the build says so with a warning.

By default the program and the packages it requires are combined into one library, so they share one package
(`.context~package~name` is the program's, and routines or classes that are not `PUBLIC` are visible to all of them).
To keep each package separate, as the interpreter does, build one library per required file:

```
RX2CPP_SEPARATE_PACKAGES=1 native/compile_program.sh prog.rex outdir
```

Each required file `name.cls` becomes `outdir/librxp_name.so` (built dependencies first), with its own package named
after its source file. Two required files with the same name are refused.

## v0.30.18 — One NUMERIC grammar; shared rule-selection implementation

`core/RxNumericClause.cls` now parses executable `NUMERIC DIGITS/FUZZ/FORM` once for standalone and native backends, with adapters retaining expression parsing and emission only. `core/RxRexxRuleSelection.cls` owns ordered rule selection for both existing registries; their differing rule sets are not yet consolidated. ooRexx 5.3 direct NUMERIC rule tests and GCC/Clang standalone/native differential smoke and rollback passed on a staged historical integration baseline. The full latest-main suites have not been rerun. See [`UNIFIED_STATEMENTS_V0318.md`](UNIFIED_STATEMENTS_V0318.md) and `tests/test_shared_numeric.sh`.

---

## v0.30.17 — Interpreter-owned object inspector

`inspector/inspect.rex` builds one inspection-only temporary package and uses ooRexx `Package`, `Class`, `Method` and `Routine` objects to recover prologue, class, instance/class-side method and routine source. PRIVATE/PACKAGE visibility is preserved from real objects; private methods do not require PUBLIC rewriting. Class-side INIT is masked in the inspection copy to prevent execution, and ::REQUIRES is rejected pending isolated dependency loading. Unchanged Crypto yields 15 classes, 104 methods, 42 routines and a 50-line prologue. **This delivers the object-model interface, not a replacement for the native code emitter or a general safe sandbox.** [Design and tests](OBJECT_INSPECTION_V0317.md).

---

## v0.30.16 — WhenDealingWith scope entry

A shared lexical code-unit scope (`core/RxWhenDealingWith.cls`) now stands between the standalone/hybrid compiler entry points and their existing clause rule registries. Package prologue, class, method, package routine, internal LABEL, PROCEDURE, and SIGNAL have explicit scope/activation policies; the synthetic native routine class is classified as a package routine. `::OPTIONS PROLOG/NOPROLOG` is retained as a package option. **This is the first structural integration, not yet a complete unified statement grammar or native `.so` prologue implementation**. The standalone and hybrid rule registries, native BIF activation bridge and complete prologue-on-`::REQUIRES` semantics still require consolidation. [Design, limits and tests](SCOPE_ENGINE_V0316.md).

---

## v0.30.15 — Native package-local routine calls

Compiled native package routines now invoke other compiled package-local `::ROUTINE`s, including private forward declarations, through positional scalar argument vectors preserving missing slots. Each invocation owns an independent activation; recursive and nested calls pass GCC/Clang interpreter parity. The ooRexx library ABI continues to use `RexxArrayObject ARGLIST` (1-based positions); object-valued argument preservation and `PARSE ARG` string conversion are separate future work. Original Crypto advances to the `X2D` BIF at line 1164 without producing a complete `.so`. See `QUALIFICATION_V0315.md` and `native/test_localcalls.sh`.

---

## v0.30.14 — positional native routine argument arrays

Native package `::ROUTINE` implementations now bind declared `USE ARG` names by position in ooRexx's `ARGLIST` array. Sparse/omitted positions remain unassigned; surplus supplied arguments are ignored. The prior arbitrary 16-position ceiling is removed. GCC and Clang pass a 15-line differential fixture with 0, 3, 4, 6, 16, and 17 declared positions. Native class-method arity remains unchanged. The unmodified Crypto package now stops at the internal `RX_MOD_INVERSE` function call at line 1147, not at `USE ARG`. See [QUALIFICATION_V0314.md](QUALIFICATION_V0314.md).

---

## v0.30.13 — IF/THEN/ELSE and DO WHILE in native routines

The existing hybrid method/routine compiler now translates restricted structured `IF` and `DO WHILE` instructions to native C++, with nested branches and conditional returns. Conditions use the existing ooRexx expression compiler. The GCC/Clang differential test covers class methods and package routines and rejects unsupported DO forms without replacing the last good `.so`. The unchanged Library `crypto.cls` advances past line 1123 and stops at line 1134 on the current two-argument `USE ARG` ABI. See [QUALIFICATION_V0313.md](QUALIFICATION_V0313.md) and `native/test_control_routines.sh`.

---

## v0.30.12 — Native `::ROUTINE EXTERNAL` and numeric activation

Restricted private `::ROUTINE ... EXTERNAL "LIBRARY ..."` declarations now
pass through to the interpreter-owned package; compiled native routine bodies
support literal `NUMERIC DIGITS`, `FUZZ` and `FORM` context settings, including
`NUMERIC DIGITS` before `USE ARG`. PUBLIC EXTERNAL, dynamic numeric arguments
and general IF/DO routine control remain fail-closed. The unchanged Crypto
source now reaches the `IF` at line 1123 but still does not compile.
See [`QUALIFICATION_V0312.md`](QUALIFICATION_V0312.md) and
`native/test_external_numeric_routines.sh` for differential evidence.

---

## v0.30.11 — private native package routines

The native `.so` backend now recognizes implicit and explicit `PRIVATE` `::ROUTINE` declarations and registers them in the interpreter-owned package without exporting their source-level routine names. GCC/Clang parity, directory-visibility checks and rollback tests are in `QUALIFICATION_V0311.md` and `native/test_private_routines.sh`. Scalar 0–2 argument bodies only; `crypto.cls` still does not compile.

---

## v0.30.8 — ooRexx native-package directive preservation

The linked-interpreter `.so` backend now retains verified `::ANNOTATE`
(PACKAGE/CLASS/METHOD/CONSTANT), raw `::RESOURCE` blocks, and resolvable
`::REQUIRES 'file' NAMESPACE name` declarations in its interpreter-loaded
source. Package annotations and resources remain accessible through ooRexx's
package objects; namespace lookup and constant getters retain native ooRexx
semantics. The parser removes these directives and opaque resource contents
from class-method translation, while validating metadata targets and preserving
physical source line numbering for diagnostics.

`::CONSTANT` now includes signed scalar numeric literals in this backend.
`::OPTIONS PROLOG/NOPROLOG` and `TRACE OFF` are accepted only in class packages
without executable prologs; native C++ method bodies still do not implement
interpreter clause tracing. Unsupported trace modes, annotation targets,
namespace forms and calculated constants fail closed. Standalone executable
compilation is unchanged. See `QUALIFICATION_V0308.md` and
`native/test_package_extras.sh` for reproducible ooRexx 5.3 differential tests.

# RX2CPP v0.30.6 — Gemini Developer Registry native compilation

See `README_V0306.md` and `QUALIFICATION_V0306.md`. The original fixture runs natively with byte-exact ooRexx 5.3 output under GCC and Clang. This is a narrowly qualified standalone class subset, not complete object-language support.

---

## v0.30.4 focused native package increment (reference §3.6)

See `QUALIFICATION_V0304.md`. The native class backend now accepts package
numeric `::OPTIONS DIGITS`, `FORM`, `FUZZ` before the first class and applies
these defaults to each compiled method activation, as well as emitting a real
`::OPTIONS` directive in the interpreter-side package source. Repeated
declarations accumulate and last value wins. Other options and later placement
are rejected rather than silently approximated. The original `crypto.cls`
now fails at its first `::ROUTINE` rather than `::OPTIONS`; Crypto has **not**
compiled. The BIF and threading implementation lanes are unchanged.

# rx2cpp v0.30.3 — Claude language patch merged with native indexed-object backend

Combined full-tree replacement based on **v0.30.2**. Claude's `claude_lang_on_v0301.patch`
adds unary logical NOT, `USE STRICT ARG`, `//`, `**`, expanded NUMERIC DIGITS and
quoted-comparison parsing fixes. It does **not** replace native class changes,
BIF implementation, or threading ownership. See `INTEGRATION_MERGE_V0303.md`
and `QUALIFICATION_V0303.md` for provenance, tests and known limits.

This is qualified language-subset coverage, **not** a claim of complete ooRexx
object semantics, general `~` dispatch, object-valued attribute storage, or
complete `FORWARD`/indexed-object support.

---

# rx2cpp v0.30.2 — native indexed setter and two-argument class ABI

This focused object-language increment extends the existing native `.so` class
backend to compile ooRexx `::METHOD '[]='` (value-first, index-second), along
with `USE ARG first, second`. Generated `::ATTRIBUTE` setters keep their
no-result semantics; ordinary selectors ending `=` may return a value.
The new interpreter-vs-native indexed object and inherited-scope fixture is
qualified under GCC and Clang. See `QUALIFICATION_V0302.md` for exact
qualifications and limits. BIF and threading sources remain unchanged.

---

# rx2cpp v0.28.1 — Claude threading/language patch integration

This release merges Claude's independently developed native thread/class-scope and
expression patch onto v0.28.0 (BIF v0.11). **BIF sources remain unchanged.**
See `INTEGRATION_CLAUDE_V0281.md` and `QUALIFICATION_V0281.md`.
The standalone compiler does not yet implement the full threaded ooRexx execution model.
RexxCPS 2.2 still rejects its decimal literal at line 72; no native benchmark is claimed.

---

# rx2cpp v0.28 — Dynamic BIF catalogue and variable-activation callbacks

This release integrates the separate BIF v0.11 delivery into the standalone
compiler *as an external module* (`external/bif`). The full 81-name catalogue
is admitted dynamically. `SYMBOL`, `VAR`, and `VALUE` use the real caller's
variable activation, including `PROCEDURE EXPOSE` aliases. Other BIFs use
qualified native implementations, explicit detached ooRexx pass-through,
or fail closed if a host activation is missing. This is not full BIF coverage.

The repaired `rx2cpp_extlib_v0.1(1)` typed native library host is checked by
an optional C++ binding test, but is not merged into compiler dispatch.
See [BIF_ACTIVATION_V028.md](BIF_ACTIVATION_V028.md) and
[QUALIFICATION_V028.md](QUALIFICATION_V028.md). All threading work stays
in Claude's separate lane. The ooRexx compiler language code remains in ooRexx.

---

> Current incremental language release: **v0.27**. See [README_V027.md](README_V027.md), [ROUTINE_ACTIVATIONS_V027.md](ROUTINE_ACTIVATIONS_V027.md) and [QUALIFICATION_V027.md](QUALIFICATION_V027.md). BIF and threading integrations remain separate.

> **Latest language lane:** v0.26 — see `README_V026.md`, `ROUTINE_ACTIVATIONS_V026.md`, and `QUALIFICATION_V026.md`. BIF and threads remain independent.

# rx2cpp v0.25 language-only update

New independent DO WHILE and DO FOREVER statement rules, with interpreter/native qualification. See `README_V025.md` and `QUALIFICATION_V025.md`. Thread implementation patches and BIF implementation remain separately owned and unmerged.

---

# Threading corpus qualification extension

Claude's independent ooRexx threading conformance corpus is preserved in `qualification/thread_corpus/`. Run `RUNS=2 tests/test_thread_corpus.sh`. See `THREADING_CORPUS.md` and `QUALIFICATION_V024_THREAD.md`. This extension does not implement native threading.

---

# rx2cpp 0.24 — structural RexxCPS language rules

See [REXXCPS_LANGUAGE_RULES.md](REXXCPS_LANGUAGE_RULES.md) and [QUALIFICATION_V024.md](QUALIFICATION_V024.md). The baseline documentation below describes v0.23 capabilities.

# rx2cpp v0.23 — PARSE SOURCE, VERSION, ARG and UPPER/LOWER

The ooRexx precompiler now has independently loadable PARSE activation-source
rules (`rules/ParseSourceModes.cls`) with runtime support in
`include/rx_parse_context.hpp`. Linux standalone executables support
`PARSE SOURCE`, `PARSE VERSION` (ooRexx reference version plus ` COMPILED`),
`PARSE ARG`, comma-separated argument templates, and `PARSE UPPER/LOWER`
transforms over the existing template engine. `PARSE SOURCE` preserves the
original canonical source path. The `.so` class backend is **not** extended
by these standalone activation rules. BIF sources remain separate and unmerged.

See `PARSE_ACTIVATION_V023.md` and `QUALIFICATION_V023.md`. Both GCC and
Clang passed 10 new focused comparison checks and 8 new syntax rejections;
23 broader PARSE comparisons, 9 rejections, 8 SELECT comparisons and 4
compound-symbol comparisons also pass with both. GCC native library
regressions pass. Full ooTest and standalone suites not rerun.

---

# v0.22 compiler update — positional PARSE templates

Added `rules/ParseTemplateRules.cls`, a separately loadable ooRexx template
ruleset, and extended the native `rx_parse_template.hpp` executor to cover
absolute/relative positional patterns, quoted delimiter patterns, and dynamic
`(variable)` delimiters. See `PARSE_RULE.md` and `QUALIFICATION_V022.md`.

Results: **17 PARSE interpreter/native parity fixtures and 9 fail-closed forms
with each of GCC and Clang**; previous SELECT and compound suites still pass.
Native GCC mixin and multi-class library suites also pass. The built-in-function
pack remains separately owned/unmerged. RexxCPS is not yet compiled unchanged.

---

# rx2cpp v0.21 — blank-template PARSE rules

This source archive advances the ooRexx-written compiler from v0.20. The separately
loadable `rules/StmtParse.cls` translates the strictly qualified `PARSE VAR`
and `PARSE VALUE ... WITH` blank-template subset. It uses
`include/rx_parse_template.hpp` for native execution.

See `PARSE_RULE.md`, `QUALIFICATION_V021.md` and `BIF_INTERFACE_CHECK.md`.
The independent BIF v0.1 zip is **not incorporated**; source-interface
compatibility testing is recorded only.

# rx2cpp v0.20 — SELECT/WHEN/OTHERWISE language ruleset

The **ooRexx-written** standalone precompiler now parses `SELECT`,
`WHEN condition THEN`, optional `OTHERWISE`, and `END`, including nested
branches, `DO ... END` branch bodies, and semicolon-separated clause forms
from the official ooTest `SELECT.testGroup`. Translation is an `if` / `else if`
chain, preserving only the first true branch and lazy evaluation of later
conditions. The loadable rule is `rules/StmtSelect.cls`; its only integration
change is registration in `core/RxRuleRegistry.cls`.

**GCC and Clang:** eight exact interpreter/native stdout comparisons, six
unsupported-syntax rejections, and a focused ooTest suite of 17 tests and 44
assertions with zero failures/errors. The official historic `SELECT` testGroup
run against ooRexx 5.3 produced **20 tests and 2 errors** because it expects
SYNTAX 34.1 where 5.3 reports 34.2. This discrepancy is recorded, not hidden.
See [SELECT_RULE.md](SELECT_RULE.md) and [QUALIFICATION_V020.md](QUALIFICATION_V020.md).

```bash
export REXX_BIN=/path/to/rexx REXX_LIB=/path/to/ooRexx/lib
export OO_TEST_ROOT=/path/to/ooTest-4.2.0-snapshot06
CXX=g++ ./ootest/run_select.sh
CXX=clang++ ./ootest/run_select.sh
```

This remains a strict-subset compiler. The full shipped RexxCPS source does
**not** compile; it still hits the unsupported decimal literal on line 72.
Native `.so` class compilation, general exception compatibility, decimal
numeric contexts, and the separately maintained built-in functions are NOT
advanced by v0.20.

---

# rx2cpp v0.19 — Compound variables and stem defaults

The **ooRexx-written** standalone precompiler now supports indexed Rexx
compound symbols, dynamic tails, and stem defaults and resets, using the
separately loadable `rules/CompoundSymbols.cls` language rule and the
interpreter-free native `include/rx_compound_symbols.hpp` symbol layer.
See [COMPOUND_SYMBOLS.md](COMPOUND_SYMBOLS.md) and
[QUALIFICATION_V019.md](QUALIFICATION_V019.md) for exact coverage and limits.

```
export REXX_BIN=/path/to/rexx REXX_LIB=/path/to/ooRexx/lib
CXX=g++ tests/test_compound.sh
CXX=clang++ tests/test_compound.sh
```

**GCC and Clang:** four byte-identical interpreter/native differential
programs and fail-closed unsupported-syntax checks passed. Four older program
comparisons passed on GCC. The full ooTest rerun was interrupted and is NOT
reported as passed. RexxCPS 2.2 still does not compile unchanged.

BIFs remain a separate developer-owned package; no built-in-function
implementation was changed in this release. This language feature is in the
**standalone executable backend**; it is not yet emitted by the native `.so`
class-package backend.

---

# rx2cpp v0.18 — RexxCPS benchmark readiness and repetition DO

The ooRexx-written precompiler now supports a separately loadable
`DO count ... END` rule (`rules/StmtRepeatDo.cls`), with a single evaluation
of the count expression and checked nonnegative `int64` execution.

**The original shipped RexxCPS 2.2 does not compile yet.** Its unmodified
reference interpreter run measured 1,789,330 clauses/second, but there is
**no comparable native RexxCPS score**. A separately identified synthetic
loop kernel derived from its DO nesting has 7-run median wall times of
0.415431s interpreted and 0.109759s native (3.785x), with byte-identical
outputs. These are not RexxCPS numbers.

See [benchmarks/REXXCPS_READINESS.md](benchmarks/REXXCPS_READINESS.md) for
feature gaps, exact scope, reproduction and provenance. Run:

```
export REXX_BIN=/path/to/rexx
export REXX_LIB=/path/to/ooRexx/lib
CXX=g++ benchmarks/test_rexxcps_progress.sh
CXX=clang++ benchmarks/test_rexxcps_progress.sh
RUNS=7 python3 benchmarks/benchmark_rexxcps_kernel.py
```

`DO count` is currently qualified for integer-valued, nonnegative counts
in the checked native `int64` subset. This does **not** implement ooRexx's
full whole-number acceptance, decimal contexts, or all forms of `DO`.

---

# rx2cpp v0.17 — native mixin inheritance and class-owned scopes

The ooRexx-written precompiler can now compile two sibling `MIXINCLASS`
providers and a concrete class with an `INHERIT` clause into one native C++17
library. The loader exports actual ooRexx classes through `::requires
'rx2cpp_mixin' library`, without Alchemy Foreign Runtime or a proxy file.
It keeps independent `(object, class scope, variable)` state and delegates
method lookup to ooRexx.

See [native/MIXIN_SCOPE.md](native/MIXIN_SCOPE.md) for exactly which graphs are
supported, and [QUALIFICATION.md](QUALIFICATION.md) for GCC/Clang tests.
The test program is `native/fixtures/mixin_scopes.cls`.

```
export OO_ROOT=/path/to/ooRexx/usr/local
export REXX_BIN="$OO_ROOT/bin/rexx"
CXX=g++ native/test_mixin.sh
CXX=clang++ native/test_mixin.sh
```

**Unsupported**: general class DAGs, SUPER, dynamic mixins, arbitrary-precision
numeric contexts and Crypto compilation. Invalid graphs fail closed.

---

# rx2cpp v0.16 — class-scope inheritance

Native package compiler now supports parent-first, within-package linear `SUBCLASS` inheritance with separate class-owned variable scopes, as tested against ooRexx 5.3. See `native/INHERITANCE_SCOPE.md` for exact guarantees and limits. BigInt/decimal activation policy is designed in `native/NUMERIC_POLICY.md` but **not implemented**.

# rx2cpp v0.15 — multi-class native .so compiler

The ooRexx-written native package compiler now accepts **multiple independent PUBLIC classes** in a single `.cls` source and publishes them as real ooRexx classes via the `RexxGetPackage` load hook. All classes share one package binary but retain distinct native dispatch and per-instance state. The first two-class fixture and original single-class ABI pass with GCC and Clang, without an Alchemy Foreign Runtime dependency. See `native/PACKAGE_COMPILATION.md` and `QUALIFICATION.md` for detailed tests and restrictions. General inheritance, class methods, routines, OO-valued returns and full crypto are NOT implemented.

---

# rx2cpp v0.14 — direct native ooRexx library output

**Actual compiler change**: `rx2cpp_native_library.rex` is written in ooRexx
and uses the existing separately loadable `RxHybridCompiler`,
`RxHybridCppEmitter`, plus new native modules: `NativeSourceGate.cls`,
`NativeLibraryEmitter.cls`, and a separately loadable source inventory.

From the same limited class source (`hybrid/accumulator.cls`), the compiler
now emits generated C++ class code and a genuine `RexxGetPackage` extension
entrypoint. On package load, a native loader creates the corresponding ooRexx
PUBLIC class and publishes it. Its methods dispatch directly to C++ state.
No interpreter-side proxy source is needed, and neither the generated code
nor the library depends on the Alchemy Foreign Runtime.

Reproduce on Linux (ooRexx 5.3.0 header/library paths need not be standard):

```bash
export OO_ROOT=/path/to/ooRexx/usr/local
export REXX_BIN="$OO_ROOT/bin/rexx"
export LD_LIBRARY_PATH="$OO_ROOT/lib:${LD_LIBRARY_PATH:-}"
export REXX_PATH="$OO_ROOT/bin:${REXX_PATH:-}"
CXX=g++ ./native/build.sh ./hybrid/accumulator.cls ./build/native rx2cpp_accumulator
export LD_LIBRARY_PATH="$PWD/build/native:$LD_LIBRARY_PATH"
rexx native/accumulator_client.rex
CXX=clang++ ./native/test.sh
```

The client needs only this loader declaration; there is **no generated Rexx
proxy `.cls`**:

```rexx
::requires 'rx2cpp_accumulator' library
```

Use the **package ID** in `::REQUIRES ... LIBRARY`, not the literal name
`librx2cpp_accumulator.so`: ooRexx 5.3 resolves the platform-specific
`lib<package>.so` name itself, and the literal filename was observed to
fail on this test host. The library must be on the platform loader's
search path. The shared library dynamically requires the C++ standard
libraries, not `librexx` or the Foreign Runtime. It nevertheless requires
an ooRexx host interpreter to execute its ooRexx class API.

## Exact limitations

- This native class backend accepts only the prior **single-class / scalar**
  subset; `.Accumulator` is not evidence of general `.cls` support.
- It emits `INIT`/`UNINIT` lifecycle methods, with per-ooRexx-instance
  compiled object state released from the registry by `UNINIT`. Long-lived
  and concurrent-object stress tests have not been qualified.
- Native return conversion currently uses length-delimited ooRexx Strings.
  It does not yet provide arbitrary object-valued methods, missing-result
  semantics or native collection values; those must be implemented before
  general object libraries can be compiled.
- The compiled C++ arithmetic is the v0.13 restricted subset; it is **not**
  equivalent to general ooRexx decimal arithmetic, notably for crypto.
- Publishing a class into the global environment is a proof-of-concept
  mechanism with an explicit collision guard, not complete per-package
  namespace fidelity.
- Unsupported `::OPTIONS`, multiple classes, routines, `::REQUIRES`
  dependencies are refused in an ooRexx preflight ruleset. No misleading
  native library is emitted.
- This does **not** yet compile native `crypto.cls`. See
  `native/CRYPTO_READINESS.md` and the inventory TSV for the exact gaps.

Qualification: see `QUALIFICATION.md`, including explicit distinction between
completed v0.14 tests and previous v0.13 suite results.

---

# rx2cpp 0.13.0-dev1 — CALL and built-in expression dispatch

**Actual compiler change:** `rx2cpp.rex` remains written in ooRexx. Three
new separately loadable ooRexx rulesets are now installed:

- `rules/StmtCall.cls` parses a constrained `CALL name argument[,argument]`
  instruction and emits a native routine invocation that updates frame-local
  `RESULT` only for an actual return value.
- `rules/ExprBuiltinCall.cls` parses function-call expressions, including
  nested built-in calls; expression evaluation **does not alter `RESULT`**.
- `rules/RxBuiltinRules.cls` owns the explicit supported built-in registry
  and argument-arity validation. Unsupported names and arity are rejected
  *before* a C++ file is written.

The current registered built-ins are **`ABS` and `LENGTH`, exactly one
argument each**. Their implementation is in the standalone C++ native runtime;
no interpreter library is linked for these cases. `ABS` currently supports
only integral values within ±999,999,999 (default NUMERIC DIGITS 9): decimal
values, larger integers, nonstandard precision and object arguments are **not
claimed equivalent**. Unsupported numeric values produce explicit runtime
errors, rather than invented results. `LENGTH` accepts the existing native
byte-string subset; interpreter-managed objects still require a bridge.

Example:

```rexx
result = 'before'
call ABS -5             -- updates RESULT to 5
x = ABS(-7)             -- x=7, RESULT remains 5
call LENGTH 'abc'       -- RESULT becomes 3
say x result
```

**Not yet supported:** `CALL` to internal labels, `::routine`, external
programs/functions, dynamic names, `CALL ON`/`OFF` condition traps,
`PROCEDURE`/`EXPOSE`, argument omissions, `SIGL`, `RC`, local frame switching,
no-result `RETURN` for an internal routine, arbitrary NUMERIC contexts,
interpreter BIF overrides, and full ooTest CALL/ABS/RESULT groups. The
underlying native `MessageResult` type can represent a missing return, but
both currently admitted built-ins return objects, so the new CALL source
compiler does **not** yet qualify the drop-RESULT path for a no-return routine.
The existing object-message tests exercise no-return independently.

The current version records selected **microcases** traceable to
`ooTest 4.2/ooRexx/base/bif/ABS.testGroup`, not as complete upstream
method passes. See `ootest/abs-call-coverage.tsv`. The full ooTest archive
is kept as an external qualification dependency. Source and native
regressions use the supplied ooRexx 5.3.0 executable as reference.

Reproduce:

```bash
export OO_ROOT=/path/to/ooRexx/usr/local
export REXX_BIN="$OO_ROOT/bin/rexx" REXX_LIB="$OO_ROOT/lib"
export OO_TEST_ROOT=/path/to/ooTest-4.2.0-snapshot06
export OO_SAMPLES="$OO_ROOT/share/ooRexx/samples"
./tests/run.sh
./ootest/run.sh
CXX=clang++ TEST_OUTPUT_DIR="$PWD/build/clang-ootest" ./ootest/run.sh
./hybrid/build_generated.sh
```

---

# rx2cpp 0.12.0-dev1 — message chaining and local RESULT state

**Actual source changes:** the precompiler is still written in **ooRexx**.
Two new loadable rule classes, `rules/ExprMessage.cls` and
`rules/StmtMessage.cls`, implement literal-selector `~`/`~~` message sends
in scalar script expressions and standalone instructions. The runtime returns
`std::optional<rx::Value>` from object messages to distinguish an absent
method return from a returned value. Only an instruction-level send sets or
drops the current frame's `RESULT`; expression sends do not change it.
Cascading returns the *receiver* (and sets `RESULT` to that receiver when
used as a standalone message instruction).

`rules/OperatorRules.cls` now explicitly sequences left-operand evaluation
before right-operand evaluation when emitting C++ binary expressions, so an
object/message expression is not reordered by the C++17 argument-evaluation
rules. `~'='(rhs)` and other **quoted** operator selectors dispatch using the
same overridable operator machinery as infix comparisons. Note that the
literal spelling `a~=(b)` is **not accepted by the supplied ooRexx 5.3
interpreter**: the operator selector must be quoted (`a~'='(b)`).

The standalone built-in string message subset is currently `LENGTH`,
`REVERSE`, `UPPER`, `LOWER`, `COPIES(n)`, `SUBSTR(start[,length])` (only the
admitted no-padding cases), plus quoted binary arithmetic/comparison
selectors. Other dynamically encountered method selectors **fail at runtime**
with an explicit diagnostic. `::class` source emits through its separate
hybrid class compiler, which deliberately rejects method sends until its
native/proxy backend can emit them correctly; it continues to pass existing
accumulator and negative tests. The `rx::ObjectDispatch` ABI lets compiled
objects supply their own return/no-return message methods but source-driven
hybrid method invocation is not yet integrated automatically.

**Example:**

```rexx
text = 'abc'
text~length                 -- RESULT = 3
text~~reverse               -- RESULT = original text ('abc')
x = text~copies(2)           -- x = 'abcabc', RESULT remains 'abc'
text~reverse                -- RESULT = 'cba'
say result
```

To reproduce the v0.12 results using a staged interpreter (no system-wide
installation required), set `OO_ROOT`, `REXX_BIN`, `REXX_LIB`, `OO_SAMPLES`,
and `OO_TEST_ROOT`, then run `./tests/run.sh`, `./ootest/run.sh`,
`./hybrid/build_generated.sh`, `./hybrid/test_compiler.sh`. Supply `CXX=clang++`
and distinct `TEST_OUTPUT_DIR` for Clang runs. `build.sh` compiles individual
sources; see `examples/message_result.rex` and `examples/message_operator.rex`.

**Scope:** the official ooTest 4.2 test group `RESULT_RC_SIGL.testGroup` is
used as a **semantics discovery** reference. The included fixtures are
selected, independently authored microcases, not a claim that any full
upstream method compiles. Traceability: `ootest/result-coverage.tsv`.
Decimal contexts, general methods, user-defined classes in the standalone
compiler, `.nil`, `CALL`/external routines, `VAR`, direct/indirect dynamic
message selectors, arbitrary object expression evaluation, and the complete
hybrid compiler self-host are still outstanding. See `QUALIFICATION.md`.

---

# rx2cpp 0.11.0-dev1 — first ooTest-driven language expansion

**Actual code change:** Four augmented-assignment statement operators (`+=`,
`-=`, `*=`, `/=`) are now compiled by ooRexx itself into C++17, by the new
loadable `rules/StmtCompoundAssign.cls` and
`rules/CompoundAssignmentOps.cls`. The lexer recognises augmented tokens
before single operators; the central statement registry registers the new
rule ahead of ordinary assignment. Emission snapshots the old left value and
RHS once before using `rx::sendBinary` (so operator-message dispatch is not
silently replaced with C++ primitive arithmetic). The standalone C++ runtime
is unchanged. The compiler is **not** self-hosting.

The initial corpus scope is deliberately honest: four **integer `i3`
subcases** based on `Assignments.testGroup` from the ooTest 4.2 archive,
plus three original composition fixtures. The 4.2 group's decimal-loop
assertions, the remaining 7 augmented operators, object arguments, and
arbitrary decimal arithmetic are **not** native-qualified. Full source
mapping: `ootest/assignment-coverage.tsv`. No upstream source is altered.

Supported arithmetic is still narrow: `+`, `-` and `*` operate on checked
signed 64-bit integers; `/` has the existing nine-significant-digit
floating approximation. This is **not** equivalent to the general ooRexx
`NUMERIC DIGITS` model. Operand evaluation order is explicitly sequenced by
the new statement emitter. Results outside that runtime subset are not yet
conformance claims.

Reproduce on Linux (or supply an appropriate Android/Termux runtime/compiler):

```sh
export OO_ROOT=/path/to/staged/usr/local
export REXX_BIN="$OO_ROOT/bin/rexx" REXX_LIB="$OO_ROOT/lib"
export OO_TEST_ROOT=/path/to/unpacked/ooTest-4.2.0-snapshot06
export OO_SAMPLES="$OO_ROOT/share/ooRexx/samples"
./ootest/run.sh              # 24 ooTest methods; byte-for-byte native parity
CXX=clang++ TEST_OUTPUT_DIR="$PWD/build/ootest-clang" ./ootest/run.sh
./tests/run.sh               # original general compiler regressions
CXX=clang++ TEST_OUTPUT_DIR="$PWD/build/qualification-clang" ./tests/run.sh
./ootest/reference-smoke.sh  # 4.2 historic groups run on 5.3 interpreter only
```

ooTest's own test runner may exit zero on failed assertions; wrappers explicitly
check the failure and error totals. This archive includes compiler source,
example fixtures, and qualification logs, but not the supplied ooTest archive
or the proprietary system toolchain. See `QUALIFICATION.md` for exact results.

---

# rx2cpp 0.10.0-dev1 — ooTest-driven conformance exploration

**New in v0.10:** Integrated the official ooTest test driver with a separate
`ootest/RX2CPP.testGroup` that checks compiler/interpreter differential
behaviour, fail-closed negative tests and selected source-level reference
semantics. An ooRexx-written source inventory (`OoTestGroupScanner.cls`)
surveys the supplied historic interpreter corpus without running arbitrary
programs. Read [`ootest/README.md`](ootest/README.md) and
[`QUALIFICATION.md`](QUALIFICATION.md) for reproducible commands and precise
version-mismatch limitations.

The **compiler and native runtime** are unchanged from v0.9; this release is a
new qualification and discovery layer, not a claim of broader language support.
The archive intentionally does not copy or modify the uploaded ooTest snapshot.

---

# rx2cpp v0.9 — ooRexx class to C++ with generated interpreter proxies

**New in v0.9:** The ooRexx-written precompiler can now translate a tightly limited *actual ooRexx class source* to a C++17 class and generate its companion ooRexx interpreter-proxy class. This is a genuine OO source-to-native compilation experiment, replacing the prior hand-coded C++ counter as the sole bridge demonstration. Class/method directives and each supported method statement live in independently loadable ooRexx rule modules. The v0.8 handwritten bidirectional bridge remains as a regression fixture, not the generator's implementation.

The source `hybrid/accumulator.cls` is executed verbatim by ooRexx for the reference oracle. The same source becomes `generated.cpp`, `generated.hpp`, `generated_proxy.rex` through `rx2cpp_hybrid.rex`. `hybrid/build_generated.sh` builds the native library and host, creates a live interpreter, registers a process-scoped macrospace routine, invokes the generated interpreter proxy and compares complete outputs to the ooRexx execution. Tests also check independent object state, native and interpreter `.Object` identity comparisons, pinned proxy lifetime, binary embedded-NUL strings, missing argument rejection, and fail-closed source translation. All pass with GCC and Clang. See `QUALIFICATION.md`.

**Class subset accepted:** one `::class Name public` (or with default visibility), several `::method Name`, `expose fields`, `use arg oneName`, simple assignment and scalar `return` expressions. The `INIT` method is special: a host must invoke it and register the new native instance. Further ooRexx syntax is rejected; there is no automatic interpreter fallback or broad class coverage. Native classes get inherited object-identity comparisons, not user-defined comparator override compilation. Macrospace lookup is not object storage; objects must be pinned in an interpreter context for stable reference identity. No hardened capability security or automatic canonical proxy cache is claimed.

**Quick demo:**

```bash
OO_ROOT=/path/to/ooRexx/usr/local REXX_BIN=/path/to/ooRexx/usr/local/bin/rexx \
REXX_LIB=/path/to/ooRexx/usr/local/lib ./hybrid/build_generated.sh
```

For cross-host/Termux, explicitly provide `OO_ROOT`, `OO_INCLUDE`, `OO_LIB`, `REXX_BIN`, `REXX_LIB`, and matching `CXX`. No Linux executable is assumed portable.

The previous v0.8 documentation is retained below for historical detail; prefer `QUALIFICATION.md` for the exact **v0.9** test scope.

---

# rx2cpp 0.8.0-dev1 — ooRexx compiler, installed sample corpus, hybrid macrospace bridge

`rx2cpp` is an **ooRexx-written**, modular source-to-C++17 precompiler. The original pure-native execution path is still present: restricted compiled programs use `include/minirexx_runtime.hpp` and have no ooRexx interpreter dependency.

This development delivery adds two independent experiments:

1. **Systematic upstream sample coverage.** The audit walks **all 55** `.rex`/`.cls` programs in the supplied ooRexx 5.3.0 debug package's `share/ooRexx/samples`, records source SHA-256 and the first unsupported construct for each, and never executes unaudited examples. A separate differential test successfully compiles the *unmodified* shipped `api/c++/callsample/HelloWorld.rex`, matching interpreter stdout and process exit. This required the new modular `rules/StmtReturn.cls`.
2. **Interpreter macrospace ↔ compiled C++ object bridge.** `hybrid/` embeds the interpreter, holds live Rexx object handles as global references, registers a uniquely named callable routine in *real* ooRexx macrospace, instantiates a Rexx proxy class that dispatches into a C++ compiled-object registry, and proves a **nested interpreter object-method call from the compiled callback**. This is linked against `librexx`/`librexxapi`. The compiled class is hand-authored as a stand-in for a future generated class; automatic mixed-mode compiler emission is not yet implemented.

## Reproduce with the supplied `.deb` extracted as an ooRexx root

```sh
export OO_ROOT=/path/to/extracted/usr/local
export REXX_BIN="$OO_ROOT/bin/rexx"
export REXX_LIB="$OO_ROOT/lib"
export OO_SAMPLES="$OO_ROOT/share/ooRexx/samples"

# Translation-only: touches no sample's runtime IO, network, prompts, or files.
samples/audit.sh

# Compile real shipped ooRexx example, and compare interpreter & native output.
./build.sh "$OO_SAMPLES/api/c++/callsample/HelloWorld.rex" build/hello-native
"$REXX_BIN" "$OO_SAMPLES/api/c++/callsample/HelloWorld.rex" > build/hello-reference.txt
build/hello-native > build/hello-actual.txt
cmp build/hello-reference.txt build/hello-actual.txt

# Macrospace + bidirectional object delegation, GCC or clang++.
OO_ROOT="$OO_ROOT" hybrid/build_and_test.sh

# Baseline 26 tests + one differential test for the shipped example.
OO_ROOT="$OO_ROOT" tests/run.sh
```

`hybrid/build_and_test.sh` accepts explicit `OO_INCLUDE`, `OO_LIB`, `OO_ROOT`, `CXX`, and `HYBRID_BUILD_DIR`. It does **not** assume a system-wide Linux installation; build paths can point into Android/Termux or a unpacked distribution. `samples/audit.sh` accepts `OO_SAMPLES`, `AUDIT_OUT`, and `AUDIT_TIMEOUT`.

## Macrospace call graph (actually tested)

```
compiled C++ executable
  ├─ C++ RexxObjectProxy --> RexxThreadContext::SendMessage --> live .Array object
  │    (RequestGlobalReference / ReleaseGlobalReference preserve identity)
  └─ scoped RexxAddMacro('RX2CPP_DEMO_<pid>', 'proxy_macro.rex')
       --> C++ CallProgram('macro_driver.rex')
          --> CALL (macroName) [ooRexx macrospace FUNCTION lookup]
             --> interpreter .CompiledCounterProxy~increment()
                --> ::routine NativeDispatch EXTERNAL 'LIBRARY rx2cppbridge ...'
                   --> compiled object registry --> native C++ method
             --> interpreter .CompiledCounterProxy~decorate()
                --> NativeDispatch --> RexxThreadContext::SendMessage1(
                       interpreter .BracketFormatter, 'RENDER', value)
                   --> compiled C++ method --> return to Rexx --> return to native
```

**Important distinction:** ooRexx macrospace stores callable compiled **program/routine definitions**, not live object instances. Live interpreter objects remain in an interpreter instance; the macrospace-resident code creates a Rexx proxy holding an opaque registry token. The compiled object remains in the native registry, and can call back into interpreter objects. In this tested ooRexx version `RexxThreadContext::CallProgram(macroName, ...)` does **not** resolve a macrospace function as a program: the small `macro_driver.rex` intentionally invokes it as a function (`CALL (macroName)`). This avoids claiming a route the actual API does not provide.

The macro is scoped to the demo process PID and normally removed with `RexxDropMacro` on exit; the bridge never clears the user's macrospace. Abrupt process termination may leave a uniquely named macro in the global service. Collision prevention uses `RexxQueryMacro`; cleanup and durability need further design before production use.

The hybrid prototype uses only one calling thread and one interpreter at a time. A token and a single .String argument are the presently admitted native-object call ABI; an interpreter object can be passed to the C++ bridge for immediate interpreter `SendMessage` delegation without losing identity. There is **no general identity-preserving serialization**, object graph transfer, runtime dispatch selection, automatic compiler fallback, or hardened token/authority model yet. Handles must never outlive the owning interpreter or be used from the wrong thread. OoRexx conditions fail closed, but detailed cross-boundary exception remapping remains unfinished.

## Systematic sample audit (first pass)

- **55** installed `.rex`/`.cls` files indexed (including the API examples).
- **1** native C++ translation candidate; **54** deliberately rejected with a location diagnostic; **0** compiler crashes or hangs during translation-only sweep.
- **1** candidate verified by interpreting *the identical source* and comparing its complete stdout + exit status: `api/c++/callsample/HelloWorld.rex`.
- The first blocking symbol for 35 sources is `.`, nine is `,`, six is `:`, and four sources are blocked initially by `|`, `\`, a non-counted `DO`, or another grammar issue. These are **first failures only**, not complete feature counts; syntax like `.array~new`, `.nil`, `::class`, functions, `PARSE`, collection indexing, `SIGNAL`, and external libraries can be hidden behind the first lexical error.
- **No shipped network/interactive/filesystem-manipulating sample was executed.** The report is reproducible from the user's interpreter installation; upstream sample code is not redistributed.

See `samples/sample-inventory-2026-10-09.tsv` for path, SHA-256, status, and exact first diagnostic. See `SAMPLE_ROADMAP.md` for staged language-rule priorities.

## What remains genuinely native vs interpreter-backed

For ordinary admitted scalar instructions: native program uses the existing `minirexx_runtime.hpp` and **does not link** ooRexx libraries. Hybrid builds explicitly link to `librexx` and `librexxapi` and use the native API; they are a separately tested route for advanced features, **not** a blanket fallback for unknown syntax. The ooRexx precompiler still rejects unsupported programs without emitting partial C++.

`::class`, `::method`, `::routine`, scoped dispatch, arbitrary ooRexx methods, numeric contexts, general expressions, and broad sample coverage are not self-hosted yet. There are no claims of compile-time/runtime speed gains for the hybrid route; crossing into the interpreter costs time and preserves interpreter semantics rather than guaranteeing speed.

## v0.30.1 object-language correction: attributes and constants

The class backend now supports separate `::ATTRIBUTE name GET` and
`::ATTRIBUTE name SET` selectors, as well as full getter/setter attributes.
`::CONSTANT` is preserved as a native ooRexx directive, supporting both
class-object and instance getters. See `ATTRIBUTE_CONSTANT_SEMANTICS_V0301.md`.
Run `native/test_attribute_constant.sh` with `OO_ROOT`, `REXX_BIN` and optional
`CXX=g++` or `CXX=clang++` for differential qualification.
