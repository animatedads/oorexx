# ooRexx MVS — LLM Gopher sphere v0.1

The MVS C Front port is the currently active Alchemy component PA-C-MVSCF.
This sphere is **documentation**, not a platform service and not a build/execute
authorization. It uses the usual Gopher profile / pack / article vocabulary.

Profile: `profiles/oo-rexx-mvs.json`.
Start: `packs/oo-rexx-mvs/00-sphere.json`.
Nine articles and a continuity corpus preserve source provenance, compiler
frontier, ABI/runtime rules, native-record semantics, unqualified alternative
backends, guest results and next acceptance gates.

## What the evidence actually supports

- Historical dev16 Linux cfront/cc370 core: **190/199** permitted units.
- dev17–dev20 host-side RecordSet, unwind, transformation and tooling tests.
- No complete MVS linked interpreter, no ooTest conformance, no recent full
  crosscompiler rerun, and no modern z/OS execution evidence.
- Mainframe ELF SDK 0.1.0 is C-only, with a separate experimental TSO31/TSO24
  host harness. Its upstream z/OS 1.5 qualification is not our execution.
- ED209Z guest RecordSet assembler failure remains a failure, not a pass.

Source details and SHA-256 archives: `SOURCE_AUTHORITY.json`.
Gopher structural checks: `tests/verify_sphere.py`, separate from actual
Gopher semantic validation and from any target execution.

This sphere intentionally does not copy or change a NotNotes component
register or an unrelated project's sphere; only a verified upstream owner
should update those authoritative records.
