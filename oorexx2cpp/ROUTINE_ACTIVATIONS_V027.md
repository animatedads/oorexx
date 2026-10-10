# Activation and variable-pool contract — v0.27

The routine callback contract is now:

```cpp
using RoutineRegistry = std::unordered_map<std::string,
    std::function<MessageResult(Variables &, const std::vector<Value>&)>>;
```

`rx::Variables` owns one local map, an optional `outer` pointer, and its
explicit `exposed` set. A procedure constructs a child scope using the
incoming caller scope. `rx::variableOwner` follows exposure aliases to the
owning activation and `rx::get`, `rx::set`, `rx::drop`, `rx::lookup`, and
`rx::resetStem` always use it. Exposing `a.` redirects the stem default and
all `a.*` entries, so resetting an exposed stem resets the caller's stem.
The alias is live and recursive; it is **not** a copied-in/copied-out value.

Without PROCEDURE, a routine binds directly to its caller's Variables object.
With PROCEDURE, it creates an isolated Variables object and exposes only
explicit named bindings. The argument vector belongs to each individual
activation, including omitted/empty argument behaviour already established
in v0.26. `CALL` writes its return value to the invoking activation's
`RESULT` only; function expression invocation does not write `RESULT`.

Object instance/class variable scopes from native .so class compilation are
not conflated with routine `PROCEDURE` pools. Activations live on the C++
call stack for this standalone synchronous compiler subset. Threading and
interpreter-backed BIF activation handoff are out of scope.

**Semantic proof points:** isolated variables, exposed parent mutation, stem
reset, recursive exposure, nested procedures, routine without PROCEDURE
sharing the caller's local scope, and result isolation. Each tested against
ooRexx 5.3.0 and compiled GCC/Clang C++ output byte-for-byte.
