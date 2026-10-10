# Native BIF block tests

Run `./block_tests/run.sh` with `REXX_BIN` and `RX2CPP_BASE` configured.
`LD_LIBRARY_PATH` must resolve the matching ooRexx interpreter libraries.
Use `CXX=clang++` or `CXX=g++` and an optional separate `BUILD_DIR`.

Matrix TSV column order: case ID, function name, block, argument bytes as
uppercase hexadecimal. `oracle.rex`/`range.rex` execute those very calls in
ooRexx, emitting hexadecimal result bytes. `native_runner.cpp` executes them
using the add-on's `rxbif::invoke`. `verify.py` checks each functional block,
not merely the overall sum. `negative_cases.cpp` checks error categories.

The `gen_matrix.py` / `gen_range.py` scripts are *test-case generators* written
in Python; the production upstream BIF-to-IR conversion and rule classes are
written in ooRexx and are inherited unchanged.
