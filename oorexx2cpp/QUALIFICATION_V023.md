# rx2cpp v0.23 — qualified PARSE activation-source expansion

Target: ooRexx 5.3.0 debug interpreter shipped as
`oorexx-5.3.0-13196.ubuntu1604debug.x86_64...deb`; native builds use C++17
GCC or Clang on Linux x86-64. Target source remains unchanged between
interpreter and native runs except for the explicit VERSION result marker.

| Qualification | GCC | Clang |
|---|---:|---:|
| New PARSE activation-source comparisons | 10/10 | 10/10 |
| New fail-closed context syntax checks | 8/8 | 8/8 |
| Broader PARSE comparisons including new non-VERSION fixtures | 23/23 | 23/23 |
| Broader PARSE fail-closed syntax checks | 9/9 | 9/9 |
| Existing SELECT comparisons | 8/8 | 8/8 |
| Existing compound-symbol comparisons | 4/4 | 4/4 |

Native `.so` mixin and multi-class package regressions passed under GCC,
including 2,000 calls and class-name collision/failed-build rollback. The
complete old standalone regression and full historical ooTest corpus were
not rerun in this qualification round.

The VERSION test compares the complete interpreter version string followed by
` COMPILED`; all ARG, SOURCE, UPPER, and LOWER output comparisons use exact
bytes. VERSION is NOT reported as byte-identical interpreter output.

The new scenarios cover `PARSE ARG` with one/multiple command words or omitted
argument, `PARSE ARG` comma templates, `PARSE UPPER ARG` and case-sensitive
literal delimiter semantics, `PARSE SOURCE` and the RexxCPS-style source
positional template, source uppercase transformation, `PARSE UPPER/LOWER VAR`,
`PARSE UPPER VALUE ... WITH`, `PARSE VERSION`, and `PARSE UPPER VERSION`.

Intentional exclusion: native shared-library method invocation metadata is
not yet sourced from ooRexx's `RexxThreadContext`; no claim of direct `.so`
PARSE activation support or of full RexxCPS compilation is made.
