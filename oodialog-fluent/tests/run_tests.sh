#!/bin/sh
# Architecture: Tom Dyer. Code: ChatGPT (GPT-6).
set -eu
task_package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
task_build_dir=$(mktemp -d)
trap 'rm -rf "$task_build_dir"' EXIT HUP INT TERM
task_compiler=${CXX:-c++}
"$task_compiler" -std=c++17 -Wall -Wextra -Wpedantic -Werror \
    -I"$task_package_dir/include" \
    "$task_package_dir/src/OodFluentCore.cpp" \
    "$task_package_dir/src/OodFluentABI.cpp" \
    "$task_package_dir/tests/model_test.cpp" \
    -o "$task_build_dir/model_test"
"$task_build_dir/model_test" "$task_package_dir/catalogue/controls.tsv"
