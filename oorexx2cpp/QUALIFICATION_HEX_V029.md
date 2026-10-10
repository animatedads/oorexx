# Language qualification: hex/binary literals on decimal v0.29 candidate

Verified on 2026-10-10 against ooRexx 5.3.0 r13196 with GCC and Clang C++17 `-O0 -Wall -Wextra -Werror` for new literal tests.

| Qualification | GCC | Clang |
| --- | --- | --- |
| `hexbin_literals.rex` (Claude's original positive fixture, 113 bytes) | byte-exact | byte-exact |
| `hexbin_focus.rex` (35 bytes) | byte-exact | byte-exact |
| `hexbin_raw.rex` (17 bytes, including D0 0D and CR) | byte-exact | byte-exact |
| Six invalid hex/binary source files | interpreter & compiler reject; no C++ overwrite | same |
| All seven decimal regression fixtures (407 lines) | byte-exact | not rerun |
| Four malformed decimal source rejection cases | pass with protected output | not rerun |
| Five numeric runtime-error checks | fail as required | not rerun |
| `decimal_full.rex` (47 lines) | included in GCC seven | byte-exact |

All listed rows were actually run. No complete ooTest or original RexxCPS benchmark pass is claimed.
