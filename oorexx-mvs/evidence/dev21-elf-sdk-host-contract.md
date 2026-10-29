# dev21: Mainframe ELF SDK host result/identity contract

Date: 2026-10-29
Project: ooRexx MVS port (Rasen Falcon lane `oorexx-mvs-port`)
Original prototype: `oorexx-mvs/experimental/elf-sdk` (dev20 state: 12 mock tests)

## Changed files

- `experimental/elf-sdk/run-sdk-host-smoke.py`: now checks `result.json`,
  `consumer.c`, `consumer.elf`, `consumer.obj` and XMIT output, with
  independent digest comparison and TSO24/31 member/AMODE/RMODE checks.
- `experimental/elf-sdk/tests/test_runner.py`: 23 negative/positive
  synthetic-consumer contract tests, including timeout and refusal controls.
- `experimental/elf-sdk/qualification.json`, README and MVS Gopher sphere:
  evidence categories, next milestones and unchanged historic frontier.

## Executed host checks

- Python unit contract controls: **23 PASS**, executed in bounded groups.
- Python compile: `python -m py_compile run-sdk-host-smoke.py tests/test_runner.py`: PASS.
- C ABI fixture: `cc -std=c99 -Wall -Wextra -Werror -pedantic -fsyntax-only z_backend_contract.c`: PASS.
- Test fixtures contain the string `FAKE ELF NOT OBJECT` and only
  manufacture `result.json` compatible with the upstream consumer's schema.
  **They do not compile or assemble any S/370 instructions.**

Negative controls covered: wrong result format; wrong copied-source SHA;
wrong XMIT SHA; wrong native member and AMODE; missing native deck or XMIT;
symlink XMIT; timeout; invalid timeout/profile; overlapping paths, existing
output, relative paths, missing SDK and failed SDK return code.

## Source authority used for the SDK output schema

Upstream: https://github.com/adesutherland/mainframe-elf-sdk
Tag `v0.1.0`:
`sdk/scripts/compiler_sdk_consume.py` records
`format=mainframe-compiler-sdk-consumer-v1`, `profiles` with
`source_sha256`, `elf_sha256`, `native_deck_sha256`,
`source_native_links.default` (XMIT hash, native member, AMODE, RMODE),
and top-level `sdk_manifest_sha256`.

## Unchanged qualification limits

- Installed mainframe ELF SDK 0.1.0 binary was **NOT_RUN** in the current
  environment; no full GCC/link/ELF inspection or real native deck was made.
- No live MVS 3.8J / z/OS guest receipt or JES qualification is asserted.
- The inherited MVS cfront -> cc370 core frontier remains **190/199**.
- The independent `oorexx2cpp/` project is untouched.
- Autobuilder was not used or invoked.
