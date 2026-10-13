# RX2CPP native nine-object coverage (development increment)

Architecture: Tom Dyer. Implementation and regression rig: ChatGPT. Independent BIF lane untouched.

## Class coverage

| ooRexx class | Natively executed operations in compiled-library mode | Delegates to interpreter |
|---|---|---|
| List | empty NEW; APPEND, ITEMS, ISEMPTY, FIRST, LAST, FIRSTITEM, LASTITEM, scalar AT / HASINDEX on minted tokens | PUT, REMOVE, INSERT, iteration, custom-index and other methods |
| Queue | empty NEW; QUEUE, PUSH, PULL, PEEK, ITEMS, ISEMPTY | other methods and collection introspection |
| Table | empty NEW; string-index PUT, AT, [], []=, HASINDEX, ITEMS, ISEMPTY | object indexes, enumeration, removal, other methods |
| Set | empty NEW; scalar PUT, HASINDEX, HASITEM, ITEMS, ISEMPTY | object equality, enumeration, algebra, other methods |
| Bag | empty NEW; scalar PUT, HASINDEX, HASITEM, ITEMS, ISEMPTY | multiplicity observations, enumeration, removal, algebra |
| Relation | empty NEW; scalar-key PUT, HASINDEX, ITEMS, ISEMPTY | ALLAT, ambiguous AT, object-index, enumeration, other methods |
| Supplier | two dense equal-length arrays NEW; AVAILABLE, INDEX, ITEM, NEXT | non-dense/other constructors, GETARRAYS, other methods |
| Message | real Message NEW through interpreter, native TARGET and MESSAGENAME projections | SEND, START, WAIT, CANCEL, NOTIFY, lifecycle conditions |
| DateTime | real DateTime NEW through interpreter, native memoised scalar YEAR, MONTH, DAY, HOURS, MINUTES, SECONDS, ISODATE, DAYNAME, MONTHNAME | calendar calculations, arithmetic, timezone conversion, setters and other methods |

All native objects implement `NativeRefBase` and materialise to the *real* interpreter object when passed outside compiled execution. Collection operations are recorded and replayed in order for that handoff. Class lookup uses `rx::nativeNineClass` exclusively in the host-library compiler mode; kernel, ordinary interpreted and hosted unit routes are unchanged. Native object strings/methods and `::REQUIRES ... LIBRARY` continue to be ooRexx's normal API.

The nine class kinds share promotion and interpreter delegation. They do **not** share bogus uniform collection semantics; each has its own implementation. The `Message` and `DateTime` implementations deliberately keep the interpreter as lifecycle/calendar authority. Their native acceleration is limited to read-only projections. No non-tested replacement of their built-in semantics is claimed.

## Qualification

`native/test_native_{list,queue,table,set,bag,relation,supplier,message,datetime}.sh` are nine independent executable test rigs using the same unchanged source against interpreted and compiled execution. `native/check_native_nine_one.sh` is their shared driver; each fixture has a pinned output checked against a live interpreter *before* a compiled result can pass. Every rig checks that the C++ generated method constructs `rx::nativeNineClass` rather than silently falling back to interpreter class selection, and that native stdout matches interpreter stdout byte-for-byte. Run each under GCC and Clang, and include in `tests/qualify.sh`.

A standalone C++ fast-path smoke built under `g++ -std=c++17 -Wall -Wextra -Werror` passes, and the nine fixture outputs match local ooRexx 5.3.0 r13196. **The current `main` native build and end-to-end GCC/Clang differential tests have not been executed locally** because current main's complete compiler tree is not available in this test container. Do not mark native execution qualified based on interpreter-only success.

### Important boundaries

1. Native Supplier NEXT on an exhausted cursor delegates to the interpreter (which raises 93.937), rather than inventing success. Native fast paths assume `.String` scalar keys with strict byte equality. Other object keys are promoted to the interpreter; work is required to qualify mixed-key hash/equality, hash order, and case-sensitive comparisons across all collection operations.
2. Lazy promotion is one-way; once promoted, all further messages use the original interpreter object. Object identity is retained when passed back to ooRexx. Concurrent native mutation and interpreter reference ownership remain distinct qualification tasks.
3. `List` APPEND tokens, deletion and re-appending require a dedicated edge-case contract before promoting fast-path REMOVE or INSERT. This increment deliberately does not implement those operations natively.
4. `Message` START/WAIT/CANCEL/REPLY and DateTime time zones and calendar rules must not be second-guessed by synthetic scheduling/calendar code. Those use the kernel.
5. Unknown method, bad arity and invalid input must be passed to the interpreter rather than silently normalised. Negative and GC stress rigs need further qualification.

## Files and integration

- `include/rx_native_nine.hpp` holds native implementations.
- `include/rx_object_bridge.hpp` appends a guarded include of the new header.
- `rules/ExprAtom.cls` selects those classes only when `RX2CPP_HOST_API` is enabled and there is no same-named user class.
- `native/fixtures/native_nine/{name}.cls`, `{name}_client.rex`, `{name}.expected` for each class.
- `native/check_native_nine_one.sh` and nine independently runnable scripts.

This is an additive development increment, not a claim of full native parity for every method on nine sophisticated ooRexx classes.

## Supplier sparse-array regression (follow-up)

An ooRexx Supplier preserves array SIZE positions, including unpopulated slots, which appear as `.NIL` during iteration. `NativeArray::snapshotItems()` returns only populated entries, so it may **never** supply a Supplier constructor unless the native array is fully populated (`slots.size() == count` and each slot present). Interpreter arrays require `SIZE == ITEMS` and per-position `HASINDEX` confirmation. Sparse inputs are sent to the interpreter unchanged. The Supplier rig now includes a three-slot pair with the middle positions missing on both sides; silently compacting both arrays would previously have produced a plausible but incorrect two-entry native Supplier.

The interpreter oracle was run using ooRexx 5.3.0 r13196 and matches the pinned two-line expected output. The isolated GCC and Clang mock fast-path gate confirms dense inputs use the native Supplier and sparse native arrays bypass the native constructor. Full RX2CPP-generated library qualification remains pending.


### Sparse Supplier versus sparse Array iteration: interpreter-verified rule

Verified on ooRexx 5.3.0 r13196: explicit Supplier~new(items, indexes) uses the input Array SIZE, not ITEMS, and retains missing positions as .NIL. This includes (a) sparse items and dense indexes, and (b) sparse items and sparse indexes. Neither may be compacted. The native Supplier NEW fast path currently accepts dense arrays only and delegates both sparse cases to ooRexx.

Separately, Array~supplier, DO item OVER array, ALLINDEXES and ALLITEMS enumerate existing entries only in array-index order. A seven-slot array with values only at indexes 1, 4 and 7 enumerates precisely 1,4,7 and one,four,seven. The same fixture checks all four routes; do not convert this behaviour into the explicit Supplier~new rule.

The native/test_native_supplier.sh regression exercises both sparse Supplier~new cases, array enumeration, and the existing dense case. Its four-line expected file was generated by live ooRexx. Full RX2CPP-generated native-library differential remains unverified.
