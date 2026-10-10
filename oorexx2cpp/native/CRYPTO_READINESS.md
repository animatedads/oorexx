# Crypto.cls native target: status at rx2cpp v0.15

Source inventoried: Library candidate `/mnt/data/files/crypto.cls`.
The inventory is supplied as `qualification/v0.15/crypto-source-inventory.tsv`
and is not a statement that the source matches an accepted authoritative
Crypto release.

The present library target supports several **independent** classes per `.so`.
Crypto has 15 classes but uses shared ancestry (CryptoHash / MD5 / SHA512,
CurvePoint / descendants), class methods, abstract methods, custom operator
methods, 42 free routines, `::OPTIONS DIGITS 2000`, array/string/object
values, and more Rexx execution instructions than our compiler accepts.

All these must retain ooRexx object semantics and numeric behaviour. As of v0.30.4, native methods can use package `::OPTIONS DIGITS 2000`
(in the supported pre-class directive position) through multiprecision
activation arithmetic. The **original source still rejects at its first
`::ROUTINE` on line 1120**; no crypto library has been compiled or published.
The standalone-program compiler and native class compiler remain different
front ends with distinct coverage.

Suggested next implementation order:
1. Unify multi-class package graph with explicit single/multiple inheritance
   resolution and defined method-overriding precedence.
2. Support class methods, abstract methods, dynamic message sends and value-
   preserving general object ABI, including identity and no-result returns.
3. Compile package routines, preserve `CALL`/`RESULT` activation contexts and
   make dependencies explicit/resolvable.
4. Add arbitrary-precision ooRexx decimal contexts before compiling crypto
   arithmetic; verify 32/64-bit word helpers and binary-string semantics.
5. Compare algorithm outputs against the actual interpreter, known-answer
   vectors and independent crypto implementations before any claim of
   secure native cryptography.

This remains a compiler-compatibility experiment, not cryptographic approval.
