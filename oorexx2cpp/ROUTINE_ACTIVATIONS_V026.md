> Historical v0.26 design, superseded for PROCEDURE handling by ROUTINE_ACTIVATIONS_V027.md.

# Restricted internal-routine activation model

A standalone program is parsed into a main program and literal labeled routines. Labels are collected from tokenized source (not raw string matches) and emitted into a native routine registry before the main body executes.

The initial ABI is:

```cpp
using RoutineRegistry = std::unordered_map<std::string,
    std::function<MessageResult(const std::vector<Value>&)>>;
```

For this first step, routines use the caller's `rx::Variables` pool, reflecting routines without `PROCEDURE`; each call has a separate argument vector. Recursion is supported by registry dispatch and the C++ invocation stack. `RESULT` is updated by `CALL` only; expression-level invocations require a result but do not explicitly update `RESULT`. A bare `RETURN` produces no result (`std::nullopt`).

The important future work is to replace lexical variable sharing with an activation abstraction supporting `PROCEDURE`, `EXPOSE` aliasing, omitted argument slots, object-valued arguments, numeric context inheritance and interpreter/native callback frames. Those semantics are not claimed by v0.26.

The compiler intentionally rejects scenarios it cannot preserve: top-level fall-through into labels, an internal routine without terminal `RETURN`, nontrivial `SIGNAL`, `PROCEDURE`, or `EXIT` within routines. One unqualified operation must never silently change runtime behaviour.
