# RX2CPP hosted tier — session adapter increment 1

Base: Claude's `hosted_tier/host_proof.cpp` on GitHub main commit `944c482`.
This adapter is an independent follow-on and **does not** wire hosted fallback into the ooRexx-written compiler.

## Purpose and public API

`HostedSession.hpp` is a small, source-level C++17 wrapper over the public ooRexx 5.3 interpreter API.
A `Session` creates one interpreter and exposes the following native-to-interpreter operations:

- `findClass(name)` — resolve a live interpreter class and retain a global reference
- `integer(...)`, `string(bytes)` — create owned scalar interpreter objects; strings preserve embedded NUL
- `send(object, selector, {args...})` — ordinary ooRexx dispatch, including dynamic class definitions and object identity
- `runRoutineSource(source, {args...})` — compile and invoke an isolated Rexx routine; **not** equivalent to `INTERPRET` inside a caller's activation frame
- `Object::asString()` — length-aware conversion after condition checking; no call on a null handle

Results have type `std::optional<Session::Object>`: an absent result is distinct from an ooRexx object.
`Object` is noncopyable and moveable. Its global reference is released on destruction. Each object retains
a shared session state so the interpreter is not terminated before the last global reference is released.

## Failure and ownership contract

- A pending Rexx condition becomes `Condition` with the full `code`, `rc`, and error message. The wrapper
  always calls `ClearCondition()` before throwing to avoid stale errors in subsequent sends.
- Inputs/outputs cannot be mixed between interpreter sessions. Foreign object arguments and receivers reject.
- Creation and destruction are **single-thread/creator-thread** only in this increment. Cross-thread method
  invocation throws, and destruction of the final handle on another thread terminates the process. The future
  integration must add an explicit attach/detach/owner-thread policy before any multithreaded use.
- Global references are not serialized or converted into stand-alone `rx::Value` objects. The object lifetime
  bridge from compiled activation frames is the next implementation boundary.
- Native library and BIF implementations are unchanged. This is not an interpreter fallback automatically invoked
  when arbitrary syntax fails to compile.

## Qualification

`OO_ROOT=/path/to/ooRexx/usr/local hosted_tier/test_hosted_session.sh`

The test links `librexx` and `librexxapi`, runs under GCC and Clang with `-Werror`, and asserts identical output:

1. Native creation of `.DateTime(2021,12,25)` and subsequent `WEEKDAY=6` dispatch.
2. Unknown message raises Rexx condition 97001 and does not poison the next successful message.
3. User subclass `define` semantics distinguish pre-definition from post-definition instances.
4. Binary-safe returned string `A` + NUL + `B` remains exactly 3 bytes.
5. `INTERPRET` executes inside an isolated hosted Rexx routine using an existing object handle.
6. A globally referenced object survives the destruction of the `Session` facade.
7. Passing an object from another interpreter session rejects without invoking the message.

Executed against the supplied ooRexx 5.3 r13196 debug interpreter: **PASS GCC and Clang**, byte-equal stdout.

## Integration next steps

1. Compiler diagnostic: distinguish `--native` (strict interpreter-free), `--hosted` (linked interpreter)
   and unsupported source, recording the exact source construct that forces hosted mode. Default remains native.
2. Create a common object `Value`/message-argument ABI that can carry pinned interpreter objects without
   converting them into strings. Preserve omitted args, absent result, and the object's owning session.
3. Define native activation <-> interpreter variable-pool handoff for `INTERPRET` and `CALL VALUE`.
   A freshly compiled routine is not equivalent to shared lexical activation state.
4. Keep callable routine precedence and the BIF implementation routes owned by the respective teams.
5. Treat macrospace as a **proposed experiment only** until registration, lookup and lifetime are qualified.
6. Differential tests need exact stdout, result identity, condition code and rc, and explicit cleanup.
