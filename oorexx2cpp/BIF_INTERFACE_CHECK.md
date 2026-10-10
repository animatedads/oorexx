# Separate BIF workstream — source interface compatibility

The independent Library package `rx2cpp_bif_source_rules_v0.1.zip` was located and **not merged or modified**. It provides separately loadable ooRexx BIF rules generated from a constrained upstream C++ source excerpt and a native C++ helper implementation. It expects the existing `rx::Value` header, with a separate per-activation BIF context. It does not replace the compiler-owned `ABS`/`LENGTH` rules.

Against the v0.21 `include/minirexx_runtime.hpp` header, running the BIF package's *unchanged* `tests/run.sh` passed under both GCC and Clang: four generated rule definitions admitted from the excerpt, nine generated-C++ tests, 86 narrow interpreter/native microcases and negative/drift checks. No full-source admission, automatic rx2cpp registration, semantic equivalence for all options or native-library binary ABI stability is implied.

The future integration boundary is an opt-in adapter from the compiler's routine-resolution framework to the BIF package's `rxbif::invoke(name, args, Context&)`; per-activation `Context` must be owned by activation frames, and omitted values/objects/conditions must not be guessed. The other development lane retains ownership of the BIF implementations.
