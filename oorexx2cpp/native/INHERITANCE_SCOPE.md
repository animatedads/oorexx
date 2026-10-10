# Native class-scope inheritance — v0.16

The compiler front end and package emitter are **ooRexx classes**, not Python.
Native output is C++17 using the public ooRexx 5.3 native-package API.

## Invariant

For each ooRexx object with a resolved class chain, **each class occurrence
has its own stable variable scope**:

    (object identity, static inheritance scope slot, variable name)

Method lookup uses ooRexx's existing object/message/inheritance implementation,
then the defining method enters its class slot. Its activation frame has
independent local variables; `EXPOSE` copies only named variables into or out
of that class slot. A nested call changes activation depth, not the fixed
inheritance scope slot. A child method never automatically reads its parent's
EXPOSEd variable with the same name.

For the compiled example, class slots are assigned in **parent-first order**:

    Root   -> native scope 1
    Branch -> native scope 2
    Leaf   -> native scope 3

They are compile-time identifiers, not dynamic call-stack depths. The runtime
registry owns one root object and lazily creates each derived class's native
field map using that object's token and class scope slot. All slots are
released together by the root's inherited `UNINIT`. The interpreter owns
canonical ooRexx object identity and dispatch precedence.

## Qualified features

- `::CLASS Root PUBLIC`, then `::CLASS Branch PUBLIC SUBCLASS Root`, etc.
- Native `.so` built from a single multi-class ooRexx `.cls` using `::requires 'package' library`.
- One shared root object token, multiple per-class native variable maps.
- Inherited methods run with their defining class's scope, even on leaf objects.
- The most-derived overriding method is chosen by ooRexx's normal dispatcher.
- Distinct object identities and their separate native inheritance scopes.
- A subclass override cannot redirect the root token lookup: native dispatch
  forwards the internal token request to the actual root class scope.
- `COPY` fails closed, since shallow copying the token would alias distinct objects.
- The native library has no direct `NEEDED` dependency on librexx or the
  Alchemy Foreign Runtime (ooRexx loads it through its extension mechanism).

## Present boundaries — NOT full inheritance

- Only linear, parent-first, within-package `SUBCLASS` chains are compiled.
- No mixins, multiple inheritance paths, metaclass alterations, or dynamic
  class-insertion/linearisation. A future graph must assign a unique slot to
  each *class occurrence*, not merely each class name.
- Only root `INIT` is implemented, inherited by children. A child `INIT` is
  rejected until generated explicit `SUPER` calls have correct semantics.
- `SUPER`, `FORWARD`, compiled object-valued arguments/returns, user-supplied
  `COPY`/`UNINIT` and all unsupported method directives remain outside scope.
- The compiler-generated native `RX2CPP_NATIVE_TOKEN` accessor is a reserved
  internal selector. A user-supplied method with that name is rejected;
  externally derived ooRexx classes may still intercept ordinary sends, so
  the compiled method explicitly forwards to its defining root scope.
- External subclasses that replace `UNINIT` without invoking the inherited
  cleanup can prevent native state release; this lifecycle boundary remains
  to be resolved before considering the backend production-ready.
- Crypto 0.8.3 and `NUMERIC DIGITS 2000` are still unsupported.

## Repeat qualification

```sh
OO_ROOT=/path/to/oorexx/usr/local \
REXX_BIN=/path/to/oorexx/usr/local/bin/rexx \
CXX=g++ native/test_inheritance.sh

CXX=clang++ native/test_inheritance.sh
```

The harness compares native and interpreter stdout byte-for-byte, exercises a
root/middle/leaf hierarchy with duplicate `value` fields, tests method
precedence, rejects invalid packages and unsafe `COPY`, and checks linkage.
