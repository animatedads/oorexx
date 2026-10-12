# Native object boundary qualification: live ooRexx identity

Architecture: Tom Dyer. Coding/qualification: ChatGPT. This test is additive; it does not change or duplicate the BIF lane.

## Why this exists

Compiled code is valuable only if a method participating in the *live ooRexx object model* preserves the interpreter's object references, rather than stringifying them or manufacturing replacements. Existing basic host-object tests do not comprehensively check multi-hop re-entry and reference replacement.

Run native/test_object_boundaries.sh with OO_ROOT, optional REXX_BIN and CXX set. tests/qualify.sh will discover it via native/test_*.sh. It uses an unchanged class source, native/fixtures/object_boundary.cls, to build a native library, and runs exactly the same interpreted client and callback code with ::REQUIRES "object_boundary.cls" or ::REQUIRES "rxboundary" LIBRARY.

## Invariants

- Class~methods reports all nine declared selectors, including ordinary instance methods; compiled objects remain examinable at the interpreter's class interface.
- .Array, .Directory, .List, .NIL and native SELF preserve identity through a native ARG/RETURN cycle. IdentityTable receives the same key after a native round-trip.
- A native method may create and return a real .Array; caller mutation is visible through all aliases, including a .Directory containing the original array.
- A method that stores an argument in its exposed variable pool can return the same object later, and can replace that reference many times.
- USE STRICT ARG x = 'default' differentiates an absent argument from explicitly passed .NIL.
- Interpreted callback methods receive the same object, and a nested interpreted → native → interpreted → native → interpreted call returns the original identity. The callback is deliberately NOT compiled.
- Four identity checks repeated 600 times must report zero mismatches. Byte-for-byte oracle and native stdout parity is required.
- The stored oracle output is verified first against the live ooRexx interpreter, so a wrong fixture cannot cause two identically wrong paths to pass.

## Qualification and limitation

Verified locally against ooRexx 5.3.0 r13196: interpreted reference completes with expected output; shell test syntax passes. The **current GitHub main native build and GCC/Clang differential have not been executed here**. The script gates those steps and fails on mismatches. Do not claim a compiled PASS from an interpreter-only run.

This test is **not** proof of all ooRexx native object coverage. Particularly unqualified: concurrent cross-thread object lifetimes, global-reference disposal after the native entry context has ended, interpreter shutdown, weak/ephemeron GC semantics, forwarding every object method, custom equality dispatch, complete method-source introspection, inherited method policy, and cross-ABI portability. The existing rxobj::release() only releases global references when its thread-local current context is active; ownership and delayed destruction must be examined separately instead of being declared safe by this test.
