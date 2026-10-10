# `::ATTRIBUTE` and `::CONSTANT` compiler semantics (v0.30.1)

These constructs are ooRexx class-language declarations, not standalone runtime fields.
The native `::REQUIRES ... LIBRARY` backend generates true method selectors, and
its interpreter-loaded class source retains `::CONSTANT` declarations.

## Rules in this qualified subset

- `::ATTRIBUTE NAME`: generates instance selectors `NAME` (getter) and `NAME=` (setter).
- `::ATTRIBUTE NAME GET`: generates only `NAME`; no setter is installed.
- `::ATTRIBUTE NAME SET`: generates only `NAME=`; no getter is installed.
- The native getter and setter share the field of the **defining class scope**;
  getters of untouched fields yield the Rexx uppercase variable name.
- `::CONSTANT NAME 'value'`, `::CONSTANT NAME 42`, `::CONSTANT NAME SYMBOL`,
  and `::CONSTANT NAME` are emitted as *ooRexx `::CONSTANT` directives*, not
  C++ instance fields. The linked interpreter supplies the constant accessor
  on both the class object and instances.
- Reserved names, duplicate selectors, bad declaration options, and unsupported
  computed constant expressions reject the build before publishing a new library.

## Limits

Native attribute storage in this backend is currently **scalar strings only**.
It does not yet implement arbitrary object-valued attributes, computed or
class attributes, delegated attributes, abstract attributes, expression-valued
`::CONSTANT`, or complete oop method bodies. `::METHOD ... ATTRIBUTE` is a
separate syntactic shorthand and is not in this release.
`::CONSTANT` support here requires the linked native ooRexx package runtime;
there is no claim of interpreter-independent constant metaclass behaviour.

## Qualification

- Reference: ooRexx 5.3.0 (`rexx` from the user-supplied debug `.deb`).
- GCC: `native/test_attribute_constant.sh`: byte-exact parity for mixed
  getters, setters, unset fields and constants; five negative builds preserve
  the previously built shared library.
- Clang: same passing result.
- `native/test_package.sh`: passed GCC and Clang (two-class isolation, 2000
  calls, duplicate/collision/reject cases, rollback).
- Other language/BIF suites were not rerun for this focused class-backend patch.

The threading and BIF implementations were not edited in this delivery.
