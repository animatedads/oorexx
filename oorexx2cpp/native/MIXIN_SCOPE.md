# Mixin scope and dispatch checkpoint — v0.17

This extension is implemented in **ooRexx**, emitting C++17 shared libraries
that are loadable via `::requires 'rx2cpp_mixin' library`. It does not depend
on Alchemy Foreign Runtime.

## Supported syntax and graph

The compiler accepts, in parent-first order:

```rexx
::class Root public
::class Salt public mixinclass Root
::class Pepper mixinclass Root public
::class Dish subclass Root public inherit Salt Pepper
::class Grand public subclass Dish
```

`PUBLIC` can occur before or after `SUBCLASS`/`MIXINCLASS` and `INHERIT`
must be the last option. In the current compiler every non-root class must
name an earlier, compiled parent, and all mixins in an `INHERIT` clause must
resolve to the same compiled root as the inheriting class. Each inherited
mixin must have been declared `MIXINCLASS` in the same compiled package.

The separate native `NativeInheritanceRules.cls` rejects unresolved/forward
mixins, mixing independent roots, duplicate explicit mixins, and repeated
inherited non-root classes through different paths. These conservative rules
may reject some legal Rexx programs; they must not silently miscompile them.

## Stable slot assignment and dispatch

Each `::CLASS` declaration gets a stable native slot number in source order:

| Class | Native slot | Defining kind |
|---|---:|---|
| Root | 1 | Root |
| Salt | 2 | MIXINCLASS Root |
| Pepper | 3 | MIXINCLASS Root |
| Dish | 4 | SUBCLASS Root, INHERIT Salt Pepper |
| Grand | 5 | SUBCLASS Dish |

The actual root token is stored in the root class's interpreter-owned object
variable scope. Native methods resolve that root token through a class-directed
native accessor; their `scopeIndex` selects the independently allocated native
field storage associated with the defining class. This is *not* the dynamic
call-stack depth. Normal ooRexx dispatch selects the method when different
classes implement the same selector. We do not substitute a C++ method
resolution order.

Two objects each have distinct root tokens, and thus separate native slots.
Native state is released by the root's `UNINIT`. Generated `COPY` deliberately
raises an error to prevent accidental state aliasing.

## Qualified / not qualified

Both GCC and Clang produced 29 stdout lines byte-for-byte identical to ooRexx
5.3.0 across two objects, two sibling mixins, multiple class scopes, class
option orderings, class membership, method override precedence, and a leaf's
derived class. Five invalid mixin graphs were rejected before binary creation.

**Not supported:** arbitrary class DAGs (especially cross-package or external
mixins), dynamic `INHERIT`/`UNINHERIT`, mixin superclass diamonds requiring
additional distinct occurrences, `SUPER`/`FORWARD`, user-defined derived
`INIT`/`COPY`/`UNINIT`, object-valued method arguments/results, and numeric
contexts requiring true Rexx decimal semantics. Slot allocation for repeated
class occurrences is not yet implemented; such graphs fail closed.

Crypto remains outside the supported subset. Do not describe this mixin work
as a Crypto compilation or a complete native ooRexx runtime.

## Reproduce

```sh
OO_ROOT=/path/to/ooRexx/usr/local REXX_BIN=/path/to/ooRexx/usr/local/bin/rexx \
  CXX=g++ native/test_mixin.sh
OO_ROOT=/path/to/ooRexx/usr/local REXX_BIN=/path/to/ooRexx/usr/local/bin/rexx \
  CXX=clang++ native/test_mixin.sh
```
