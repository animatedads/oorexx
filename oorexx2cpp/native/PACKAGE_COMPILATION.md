# rx2cpp 0.15: multi-class native ooRexx library

The compiler front end, package parser and emitter are implemented in ooRexx.
It generates a C++17 shared library exposing PUBLIC ooRexx classes using the
supported ooRexx extension ABI. The consumer uses normal ooRexx `::REQUIRES`:

```rexx
counter = .Counter~new(10)
say counter~add(5)
::requires 'rx2cpp_dual' library
```

Build and test (Linux, GCC or Clang):

```sh
export OO_ROOT=/path/to/staged/ooRexx/usr/local
export REXX_BIN="$OO_ROOT/bin/rexx"
export LD_LIBRARY_PATH="$OO_ROOT/lib:$LD_LIBRARY_PATH"
CXX=g++ native/build.sh native/fixtures/two_classes.cls build/demo rx2cpp_dual
export LD_LIBRARY_PATH="$PWD/build/demo:$LD_LIBRARY_PATH"
"$REXX_BIN" native/fixtures/two_classes_client.rex
CXX=clang++ native/test_package.sh
```

The compiled library is named `librx2cpp_dual.so`; the `::REQUIRES LIBRARY`
package identifier is `rx2cpp_dual`, NOT the literal `librx2cpp_dual.so`
filename on this tested ooRexx 5.3 host. The native methods are published as
normal ooRexx public classes, and the source does not need to be present in
order to load the compiled `.so`.

## Implemented

- Multiple independent `::CLASS ... PUBLIC` declarations in one source file
- Per-class `::METHOD` dispatch with class-qualified C symbols, including
  methods sharing the same selector name in different classes
- Two independent native-backed ooRexx object identities and instance states
- Interpreter-compatible lookup and inherited basic .Object comparisons
- Direct extension-module load hook with collision guard on every class name
- Native code with no dynamic `librexx`, Alchemy, or Foreign Runtime linkage
- Lexer-based detection of class boundaries, ignoring commented/quoted fakes
- Build staging to preserve previous output on failed compile or link

## v0.16 limited inheritance extension

See `INHERITANCE_SCOPE.md` and `test_inheritance.sh`. The separate class-scope state maps are indexed by compiler-assigned stable scope slots; root/middle/leaf inheritance, overridable methods, and identity passed with GCC and Clang. `COPY` is rejected until independent full-scope clone semantics are available.

## Deliberately unsupported

- Mixins, multiple inheritance, non-linear class graphs, and derived `INIT`
- `::METHOD ... CLASS`, `ABSTRACT`, `ATTRIBUTE`, `GUARDED`, custom operator
  selectors, `SUPER` and `FORWARD`
- Package `::ROUTINE`, `::REQUIRES` dependencies and `::OPTIONS`
- Arbitrary object-valued arguments or return values (String scalar only),
  method argument counts >1, numeric contexts beyond current restricted subset
- Compiler-owned per-package namespace isolation/transactional registration,
  external library ABI stability across interpreter versions and stress-tested
  cross-thread lifetime behaviour

The package preflight fails closed on unsupported directives. This release is
NOT a replacement for the original `crypto.cls`. The candidate source has
15 classes, 90 methods, 42 routines and `::OPTIONS DIGITS 2000`; further
language implementation is required before its cryptographic algorithms can
be compiled and independently qualified.
