# BIF breadth-first inventory — v0.5

Authority: ooRexx `interpreter/expression/BuiltinFunctions.cpp`, Git blob
`05ea58114e9e5b59a1cceebf8dd418b78058d342` (the reference text inspected for 81 BUILTIN macro names and arities).

The package DOES NOT modify rx2cpp. It does not claim full interpreter equivalence.

| Boundary | BIF names | Execution contract |
|---|---:|---|
| Existing native add-on | 36 | Native C++ subset, with optional fallback after a native restriction/error |
| Existing rx2cpp native ABS/LENGTH | 2 | Keep original implementation; optional interpreter fallback |
| Isolated ooRexx chain-back | 13 | Real interpreter 5.3 API; scalar/byte-string results and optional holes; fresh activation, NOT shared state |
| Host live-activation callback | 30 | Names/arity/rules emitted. Caller MUST supply an activation-preserving executor, otherwise explicit error |
| **Names with explicit routes** | **81** | **100% inventory reachability; NOT 100% usable by default** |

**Known native availability with optional embedded ooRexx bridge: up to 54 BIF names**, subject to supported native subsets and the isolated-mode limitations. The other **27 names are not implemented by this release**; they have source rule classes and a host callback boundary, not a built-in default implementation. `MAX`, `MIN`, `XRANGE` use open-ended arity (`-2` in the ooRexx IR; size_t maximum in C++).

## Why not invoke all 81 BIFs in an isolated interpreter?

`ARG`, `VAR`, `VALUE`, `SYMBOL`, `TRACE`, `SOURCELINE`, `DIGITS`, `FUZZ`, `FORM`, `ADDRESS`, the condition, stream/queue, environment, external-function, and local-scope BIFs obtain meaning from their *own activation, stream registry, numeric context or authority*. Calling them in a new Rexx activation can return an apparently valid but wrong result, or have an unintended side effect. They remain live-host-only. `DATE/TIME` keep v0.4 native activation-stable behaviour (also live-host eligible); `RANDOM` needs an activation-consistent generator, not a new detached call each time.

## Generation: ooRexx, not Python

`bif2breadth.rex` -> `BifSourceReader.cls` -> `BifBreadthRouteRule.cls` -> `BifBreadthEmitter.cls`. These are all ooRexx programs/classes.

The generated intermediary includes source line, name, arity, routing kind and provenance.  The generated `Bif_*.cls` is a loadable ooRexx rules class. The generated `rxbif_breadth_generated.hpp` contains a per-BIF inline C++ wrapper that calls the appropriately chosen native/bridge boundary. A bridge wrapper is **not** an inlined native implementation. Nine fully-native inlined BIFs remain in the v0.4 generator; native optimisation can continue independently.

A changed/upstream-missing signature is REJECTED. If a native forwarding method no longer matches its qualified shape, the breadth rules downgrade it to HOST_ACTIVATION rather than silently treating it as the old native implementation. The runtime does not automatically bind itself into rx2cpp's registry.

## Normal regeneration

From this add-on root:

```sh
mkdir -p generated
rexx bif2breadth.rex /checkout/ooRexx/interpreter/expression/BuiltinFunctions.cpp generated
```

On the pinned reference source, the expected inventory is 81 names. This environment had the binary interpreter and a **12-definition verbatim upstream excerpt**, but not the complete original C++ source saved locally. The supplied **81-definition signature fixture is synthetic** and is used only to exercise parsing, dynamic arity and class emission. It is not an upstream source-code replacement, and its 81 generated rules should not be confused with fully source-verified native conversions. Real-source full-file regeneration must be repeated by the integration lane against the chosen ooRexx checkout.

## Runtime opt-in

Supply `rxbif_breadth::Context(nativeContext, handler)`. The handler receives `(UPPERCASE_BIF_NAME, std::vector<Slot>)`, where `Slot = std::optional<rx::Value>` and `std::nullopt` means an **omitted** Rexx argument. The handler must preserve the current activation's data and authority when needed. To force the handler for a BIF despite native support, set `ctx.preferChainback=true`.

For the 16 isolated-safe scalar built-ins, an optional `IsolatedOoRexx` adapter can implement the callback. It uses `RexxCreateInterpreter`/`CallProgram` and a name-whitelisted `.rex` script. It preserves binary strings, argument order, optional holes and Rexx error signalling by throwing; it does **not** carry object identities, decimal precision context, user-defined built-in overrides, original source position or original activation. It must be bound intentionally; linking the extension never activates it implicitly.

`IsolatedOoRexx` is not thread-safe: create one instance per calling thread or externally serialize access. The file `native/isolated_chainback.rex` must be found by the runtime. `RexxCreateInterpreter` requires ooRexx libraries at build and run time; builds without the optional adapter continue to be interpreter-free.

## Tests and safety

- 81 names unique and matched to source pin, 81 explicit C++ and ooRexx per-BIF route entrypoints under synthetic signature-only fixture.
- Real 12-BIF upstream excerpt scanner admits 12 and explicitly reports the other 69 missing, with nonzero status.
- GCC/Clang C++17 -Werror: PASS.
- Real ooRexx interpreter execution of all 16 isolated-route names, plus one omitted middle-argument variant: PASS (17 cases).
- Explicit live-host callback loops over all 81 names: PASS (routing only).
- Existing v0.4 regression: 37 generated C++, 110 native/interpreter, 49 DATE/TIME per timezone and 21 clock-contract cases: PASS.

Upstream ooRexx implementation remains subject to its Common Public License v1.0 and notices, and is not redistributed here. Native wrappers/additions are independent original implementation work.
