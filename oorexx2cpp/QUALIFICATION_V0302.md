# rx2cpp v0.30.2 — indexed native class setter

10 October 2026. Focused object-language compiler extension, based on the complete
v0.30.1 attribute/constant delivery. Compiler source and rule classes remain ooRexx;
C++17 is generated and compiled into ordinary ooRexx native `.so` packages.

## What changed

- Native `::METHOD '[]='` is now accepted using a two-positional-scalar-argument ABI.
- ooRexx indexed assignment calls `[]=` with **value first, index second**. This
  was checked against the ooRexx 5.3.0 interpreter, and the compiled method
  receives those arguments in precisely that order.
- `USE ARG first, second` is admitted in the class-method compilation subset.
  A third argument, missing second name or duplicate name is rejected.
- Generated native object classes implement `invoke2` and the native package
  dispatcher routes zero-, one- and two-argument method invocations distinctly.
- A method selector ending `=` does **not** automatically imply an ooRexx
  attribute setter. An ordinary `::METHOD '[]='` may return an object result
  (currently a scalar string), while a generated `::ATTRIBUTE` setter returns
  no result object. Distinct method metadata now controls this behaviour.
- Two-class differential fixture checks inherited `[]=` dispatch, defining
  class-scope ownership, and state isolation across unrelated instances.
- Generated methods that have no methods at a particular arity compile cleanly
  under `-Wall -Wextra -Werror` (unused parameters explicitly ignored).

Files directly changed: `hybrid/compiled_registry.hpp`,
`hybrid/compiler/{RxHybridCompiler,RxHybridCppEmitter,RxHybridMethod}.cls`,
`hybrid/rules/{HybridMethodDirective,HybridUseArg}.cls`,
`native/{NativeLibraryEmitter.cls,native_package_template.cpp.in}`.
New fixtures are `native/fixtures/index_setter*` and test runner
`native/test_index_setter.sh`.

## Completed qualification

Reference interpreter: user-supplied ooRexx 5.3.0 r13196 debug build, staged
under a nonstandard path. Native toolchains: GCC and Clang, C++17.

| Suite | GCC | Clang |
| --- | --- | --- |
| `native/test_index_setter.sh` | PASS | PASS |
| `native/test_attribute_constant.sh` | PASS | PASS |
| `native/test_inheritance.sh` | PASS | PASS |
| `native/test_mixin.sh` | PASS | PASS |
| `native/test_package.sh` | PASS | PASS |
| `native/test_selfsend.sh` | PASS | Not run for this focused checkpoint |

The indexed-setter fixture performs byte-for-byte interpreter/native stdout
comparison (both class instances and subclass) plus three negative-build
rollback tests. The attribute/constant fixture performs byte-for-byte parity
and five rollback-protected negative cases. The existing package regression
includes 2,000 native calls; the SELF-send regression includes four threads
with 2,500 bumps each. Logs from completed suites are retained in
`qualification/v0302/`.

`native/test_threads.sh` generated PASS output in the GCC log, but its invoking
tool timed out before capturing a completed command status; it is **not**
counted as a qualified completion here. Likewise, a broader hex/BIF regression
invocation timed out; numeric, external-library, full standalone and upstream
ooTest suites were not completed in this v0.30.2 session. These subsystems
were not modified; absence of modifications is not a new regression pass.

## Reproduce

```bash
# Use the matching user-supplied ooRexx debug interpreter, headers and libraries.
export OO_ROOT=/path/to/ooRexx/usr/local
export REXX_BIN="$OO_ROOT/bin/rexx"
export REXX_LIB="$OO_ROOT/lib"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
CXX=g++ native/test_index_setter.sh
CXX=clang++ native/test_index_setter.sh
CXX=g++ native/test_attribute_constant.sh
CXX=clang++ native/test_attribute_constant.sh
```

## Known boundaries

- Native class arguments, return values and stored fields still use the
  **scalar string** subset. Object-valued attribute storage, object identity
  across native field storage, and general object-receiver sends remain open.
- Compiled class method signatures accept at most two positional scalars;
  no sparse/missing argument semantics or array-of-argument dispatch is claimed.
- `[]=` now compiles as a class method, but full arbitrary indexed l-values,
  chained `~` sends and `FORWARD` targets/options are **not** qualified by this
  change. `FORWARD MESSAGE` remains a restricted pre-existing feature.
- This is a native `.so` package extension, not an interpreter-independent
  implementation of ooRexx's entire object model.
- `CompiledObject` gains a virtual method, so native class libraries must be
  rebuilt from matching generated C++ rather than mixing old/new C++ ABI artifacts.
- BIF routes and Claude-owned threading implementation were not edited or merged.
  The separate supplied v0.16.1 BIF delivery remains a distinct integration lane.
