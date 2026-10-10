# RX2CPP v0.30.14 — ooRexx positional ARGLIST binding for native package routines

## Integration and semantics

Native `RexxRoutine1(..., ARGLIST, args)` receives the interpreter-supplied
`RexxArrayObject`. The package-routine ABI now decodes `ArraySize` and
`ArrayAt` by **position**, retaining sparse holes in a
`vector<optional<string>>`. The compiled routine creates a fresh activation
variable pool, associates each source `USE ARG` name with its corresponding
**present** array element, leaves absent or explicitly omitted names unbound,
and ignores surplus supplied arguments. This matches ooRexx `USE ARG` rather
than requiring exact supplied and declared arity.

The old 3–16 upper bound was an RX2CPP prototype restriction, not an ooRexx
semantic requirement. No fixed arity cap remains in the generated routine
method interface. The previous 0-, 1- and 2-argument native package-routine
paths also use the same array decoder now. The native **class-method** ABI is
unchanged (up to two scalar argument positions). Byte strings are
length-preserved; native object-valued arguments and omitted positions in
class-method declarations are not newly implemented.

This is an ooRexx-written compiler generator change, not a BIF or threading
implementation. It changes these source components:

- `hybrid/compiled_registry.hpp`: sparse positional native routine interface.
- `hybrid/compiler/RxHybridMethod.cls`: named argument inventory without
  an arbitrary 16-position cut-off.
- `hybrid/compiler/RxHybridCppEmitter.cls`: map present positional slots to
  declared names and preserve unassigned-name semantics for missing slots.
- `native/NativeLibraryEmitter.cls`: one decoded `ARGLIST` path for every
  native package routine, including routines that declare no `USE ARG`.
- `native/test_multiarg_routines.sh`: existing and extended differential
  fixtures, plus atomic rollback/fail-closed checks.

## Qualification against ooRexx 5.3 r13196 (Linux x86-64)

| Qualification | GCC | Clang |
|---|---|---|
| `native/test_multiarg_routines.sh` | PASS | PASS |
| 15-line byte-identical interpreter/native output | PASS | PASS |
| 0, 3, 4, 6, 16, 17 declared positions | PASS | PASS |
| Missing / explicitly omitted / surplus supplied arguments | PASS | PASS |
| Existing numeric modular power (three-arg routine) | PASS | PASS |
| PRIVATE routine invisible to external source | PASS | PASS |
| Rejections (duplicates, invalid USE ARG holes, class three-arg, unsupported function call), previous library checksum stable | 4/4 | 4/4 |
| `native/test_native_routines.sh` (PUBLIC/class parity, 7 guarded rejects) | PASS | Not rerun |
| `native/test_private_routines.sh` (PRIVATE package metadata/handle, 8 guarded rejects) | PASS | Not rerun |
| `native/test_external_numeric_routines.sh` | Initial parity and private rxmath handle checks PASS; first three guarded rejects PASS; total suite timed out | Not rerun |

Previously valid three-argument and seventeen-argument declarations were
removed from old *rejecting* fixtures; they now belong to positive tests.
Rejected forms in those fixture slots use malformed `USE ARG` declarations.

Reproduce with
`OO_ROOT=/path/to/ooRexx REXX_BIN=/path/to/rexx CXX=g++ native/test_multiarg_routines.sh`
(and repeat with `CXX=clang++`).

## Original Crypto probe

The unmodified Library `crypto.cls`, SHA-256
`fb89e345e2251964e1e6d2f16f6fa2650e4f6eda7adf7eea0f24411809aa49f5`,
now passes the `USE ARG base, exp, mod` declaration. Native compilation
stops at line 1147, column 29 on the internal routine/function call
`RX_MOD_INVERSE`, reported as:

```
rx2cpp:1147:29: native package routine/function invocation is not yet supported: RX_MOD_INVERSE
```

No usable Crypto `.so` was produced; input was left unchanged. The next
compiler integration task is scoped package-local routine-call resolution,
not further hardcoded argument positions.
