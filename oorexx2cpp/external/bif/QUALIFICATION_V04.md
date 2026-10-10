# rx2cpp independent BIF rules v0.4 — qualification

* **Build target**: untouched rx2cpp v0.20 `include/minirexx_runtime.hpp`.
* **Converter**: ooRexx 5.3.0 r13196, `bif2inline.rex` and `*.cls`.
* **Source fixture**: 12/12 canonical upstream BIF definitions admitted,
  including TIME. The offline excerpt does NOT contain DATE; the actual
  full upstream file is accepted separately as an input to the generator.
* **Native generated headers**: 37 checks passed (9 direct inline implementations,
  3 inline wrappers to independent native helpers).
* **General interpreter/native parity**: 110 byte-for-byte cases.
* **Additional DATE/TIME oracle**: 49 cases in each of five timezones
  (UTC, London, New York, Kolkata, Auckland); all passed.
* **Native DATE/TIME contract checks**: 21 passed.
* **C++ compilers**: GCC and Clang C++17, `-Wall -Wextra -Werror -O2` (both passed).
* Source method drift, call-shape drift, unrecognised/dynamic arity are
  rejected by the ooRexx rules and negative tests.

The semantics remaining unsupported or unqualified are listed in
`CLOCK_SEMANTICS.md`. This package makes no claim that unchanged rx2cpp
has adopted these rule classes or that clock support covers all original
upstream test groups.
