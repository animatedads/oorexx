# dev19 — translation-driver admission hardening

Qualification date: 2026-10-11.

## Changes

- `SWEEP_MODE=residual` processes the **nine dev16 remaining units only**.
- Require the pinned ooRexx Git HEAD and a clean worktree; **do not run `git checkout`** in the caller's source tree.
- Check required cfront/cc370 executables, source file presence and output directory safety **before** deleting previous output or writing generated files.
- Reject work paths overlapping the source/toolchain or containing symlinked output directories; propagate preflight failure exit status.
- `MVS_PREFLIGHT_ONLY=1` checks admission without touching the work/output tree.
- Wire `runtime/MvsUnwind.cpp` in the relocated dev18 repository layout, falling back to the former top-level location.

## Linux host regression

```sh
python3 -m unittest discover -s tests -p 'test_dev19_preflight.py' -v
bash -n oorexx-mvs24-cfront-bulkpass-dev16.sh
```

Result: **12 of 12 preflight regression tests passed**, plus Bash syntax validation. Tests create a temporary synthetic Git source checkout and fake tool executables. They verify correct rejection and preservation of prior evidence. They do **not** run a real compiler.

## Focused nine-unit repro (requires installed pinned tools)

```sh
OOREXX_SRC=/path/to/clean/pinned/ooRexx \
CFRONT_SRC=/path/to/cfront \
CC370_SRC=/path/to/cc370 \
WORK=/path/to/new/output \
SWEEP_MODE=residual \
bash oorexx-mvs24-cfront-bulkpass-dev16.sh
```

Pin: `de1db87f486d430d1faa9151b8a2d5f328ab70f2`.

## Scope and limits

This is a dev19 **tooling/qualification-hardening checkpoint** only. The source translation frontier remains inherited at **190/199** from dev16. No cfront/cc370 execution, MVS link-edit, JES runtime execution or ooTest conformance is claimed for dev19.
