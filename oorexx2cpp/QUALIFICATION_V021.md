# rx2cpp v0.21 qualification — 2026-10-10

Interpreter oracle: user's staged ooRexx 5.3.0 r13196 Linux debug build.

| Qualification | GCC C++17 | Clang C++17 |
|---|---:|---:|
| PARSE interpreter/native byte-identical programs | 9/9 | 9/9 |
| PARSE unimplemented syntax rejected with no partial C++ | 7/7 | 7/7 |
| Prior SELECT byte-identical programs | 8/8 | 8/8 |
| SELECT no-match failure and malformed syntax tests | pass | pass |
| Prior compound-symbol byte-identical programs | 4/4 | 4/4 |
| Compound unsupported-object rejection | pass | pass |
| Separate BIF v0.1 generated-header tests | 9/9 | 9/9 |
| Separate BIF v0.1 narrow differential tests | 86/86 | 86/86 |

C++ was compiled with `-std=c++17 -O2 -Wall -Wextra -Werror`. This is a targeted qualification matrix, **not a rerun of the complete ooTest corpus**, general Rexx language compatibility, Crypto, or whole RexxCPS.

The separate BIF package was tested against v0.21's **source-level runtime interface only**. It was not incorporated into the compiler's routine registry and must not be counted as new compiler BIF coverage. The older standalone compiler and native-library suites have not been rerun completely for v0.21.

Reproduce from the root of this archive:

```sh
export REXX_BIN=/path/to/rexx
export REXX_LIB=/path/to/ooRexx/lib
CXX=g++ tests/test_parse.sh
CXX=clang++ tests/test_parse.sh
CXX=g++ tests/test_select.sh
CXX=clang++ tests/test_select.sh
CXX=g++ tests/test_compound.sh
CXX=clang++ tests/test_compound.sh
```

For the independent BIF pack, unpack its v0.1 archive elsewhere and run `RX2CPP_BASE=/path/to/this-release ./tests/run.sh`, then again with `CXX=clang++`. Do not copy BIF source into this compiler package.
