# BIF v0.13 — optional rx2cpp v0.28 activation interoperability

**Ownership:** this is an independent BIF distribution. It does **not** change, vendor,
patch, or overwrite rx2cpp v0.28, Claude's thread/logic patch, or rx2cpp-extlib.
All C++ includes to rx2cpp and extlib resolve **externally at build time**.

## What is actually executable

`rxbif_v028::Router` is an optional caller-created adapter. Supply:

- `rx::BifRuntime&` from the unchanged v0.28 compiler.
- `PoolSupplier` returning the currently valid `rx::Variables*` **on every call**.
- Optional original-frame `FrameSupplier` to execute scalar `ARG` and `ADDRESS`.
- Optional original-activation `ControlProvider` to execute scalar
  `SOURCELINE`, `TRACE`, and `CONDITION` through v0.12's control router.

`DIGITS`, `FUZZ`, `FORM` are now read directly from **the current v0.28
activation pool**, including nested `PROCEDURE` pools, with numeric invariants
checked. `SYMBOL`, `VAR`, and `VALUE` reuse rx2cpp v0.28's **existing** live
`rx::frameVariableReply` implementation and its `PROCEDURE EXPOSE` alias
resolution. All other names continue through `rx::dispatchBif`, whose native
coverage gaps and detached interpreter limitations are unchanged.

Neither `FrameSupplier` nor `ControlProvider` is implemented by the rx2cpp
v0.28 runtime. The integration owner must provide them from a genuine compiled
activation. Merely compiling this optional adapter does not make those BIFs
available in a generated rx2cpp program. No fallback to invented context is
allowed. Scalar-only and Rexx object-identity restrictions remain.

## External typed-library host boundary

`rxbif_v028::TypedHostBridge` binds the supplied extlib v0.1b-style `Host` to a
`PoolSupplier`, **not a captured/stale `Variables&`**. Raw variable hooks
resolve compound names with the caller's current tails. Literal stem-tail
hooks deliberately do not resolve a tail as another variable.

Call routines with `TypedHostBridge::call`, which refreshes `digits`, `fuzz`
and `form` immediately before **each typed external routine**. Calling
`rxext::Host::call` directly bypasses this guarantee; the optional adapter
cannot intercept arbitrary direct host calls. Do not use the host after its
activation supplier or its underlying `Variables` has expired. Its native
library packages and ooRexx headers are external dependencies and **not**
redistributed here.

Object-valued variable reads fail before string conversion. Invalid numeric
snapshots fail before invoking the external routine. The host retains its own
exception codes; they are not converted into BIF subset-fallback signals.

## Rule generation remains ooRexx

The existing `bif2breadth.rex`, `frame/bif2frame.rex`,
`variables/bif2variables.rex`, and `control/bif2control.rex` are unchanged.
They read upstream BIF C++ declarations and produce intermediary and `.cls`
rule files. This version adds an **optional integration layer**, not another
unverified hand-coded BIF replacement. Source rules for these BIFs are already
inherited from the separately maintained distribution.

## Build-only, read-only dependency example

```sh
export RX2CPP_BASE=/path/to/unpacked/rx2cpp_oorexx_v0.28_bif_activation
export RX2CPP_EXTLIB_ROOT=/path/to/unpacked/rx2cpp_extlib_v0.1
export OO_ROOT=/path/to/ooRexx/usr/local
CXX=g++ ./activation/tests/run.sh
CXX=clang++ ./activation/tests/run.sh
```

The test uses a controlled caller-frame and control-provider fixture to verify
API and semantic boundaries. It does not claim the unmodified compiler emits
those frame/control providers. The v0.28 compiler's native variable BIFs use
its genuine EXPOSE-aware variable pool.

Both optional host objects are **not automatically thread-safe**. Scope each to a single
invoking thread or serialize them under the owning runtime, and do not let
callbacks retain expired variable pools.
