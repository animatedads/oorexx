# ooRexx MVS / z/OS — Mainframe ELF SDK backend experiment

**Experimental. No new ooRexx core translation pass, SDK release build or z/OS guest execution is claimed.**

## Scope

Retain the existing MVS 3.8J/TK5 cfront -> cc370 toolchain and QSAM/RecordSet
runtime. Independently test the Mainframe ELF SDK C compiler backend and its
native TSO packaging, initially for **z/OS31** and secondarily TSO24. Modern
z/OS guest qualification has its own evidence/authority path, independent
of the TK5/Hercules deployment on ED209C/ED209Z.

SDK upstream: <https://github.com/adesutherland/mainframe-elf-sdk>

Release **v0.1.0**, source release record commit
`f5a57fec88fe38678663c7015261131875bdfcde` (2026-10-03); repository `main`
inspected at `8801bfe1f4b554b21a435bdf8b049b20bb2eb49e`, `develop` at
`a9aa863c6b657128522b41252b7b72785020e912` (2026-10-12).
Linux x64 SDK release archive SHA256:
`b8c4c9dfba07122d6983a6aa84d9e00681572630a1dccc6bcf268099ac75ef61`.

SDK 0.1.0 uses GCC 16.2.0 and binutils 2.47 and provides **a C compiler,
not C++**. An ooRexx candidate retains cfront unless a separately
qualified C++ frontend emerges. SDK uses ELF *internally* and exports native
TSO decks and XMIT. Modern `tso-zos31-v1` on z/OS 1.5 demonstrated entry,
return and selected sequential/PDS reads. TSO24 demonstrated entry and return
only, with dataset I/O specifically excluded. The TSO24 native entry/runtime
uses z/OS-oriented SVC conventions and static callback storage; it is not
MVS 3.8J-qualified and cannot replace RecordSet or the MVS SJLJ runtime.

## Smoke (requires the separately downloaded, unpacked, installed SDK)

Download from <https://github.com/adesutherland/mainframe-elf-sdk/releases/tag/v0.1.0>
and verify the published SHA256 before unpacking. The original SDK is never
vendored or changed by this experiment.

```sh
python3 run-sdk-host-smoke.py --sdk /absolute/sdk \
    --profile tso-zos31-v1 --out /absolute/new-output-zos31
python3 run-sdk-host-smoke.py --sdk /absolute/sdk \
    --profile tso-zos24-v1 --out /absolute/new-output-tso24
```

The harness invokes the **SDK's own consumer**, records the profile, source
and SDK-manifest SHA256, consumer status and actual XMIT hash in JSON. It
requires a new output directory, rejects overlapping paths and never deletes
existing output. It explicitly records `guest_executed=false` and
`guest_qualified=false` even if the host build succeeds. Both profiles use
the same deliberately small `z_backend_contract.c`, checking ILP32 and
big-endian layout and returning 42 only **on target execution**.

```sh
python3 -m unittest discover -v -s tests
cc -std=c99 -Wall -Wextra -Werror -pedantic -fsyntax-only z_backend_contract.c
```

The contract tests use a **fake** SDK consumer, not a real compiler. A passing
fake-consumer test is evidence of harness behavior only. Installed SDK
compilation, ELF/ISA inspection, native link and actual z/OS execution remain
**NOT_RUN** in the present environment.

## Qualification gates

1. Real installed SDK v0.1.0 consumed under Linux with its SHA-checked archive
   and manifest, for both TSO31 and TSO24. Verify nonempty XMIT and record the
   full SDK consumer transcript. Do not infer guest RC 42.
2. Generate C from the pinned ooRexx cfront source and assess old-style C,
   pointer casts, relocations, language mode, compiler diagnostics and floating
   arithmetic. Preserve `190/199` until a complete qualified compiler matrix
   changes that evidence; an alternate C backend does not clear cfront failures.
3. Check ABI and S/370/s390 instruction selection, C entry/exit, `setjmp`/
   `longjmp`, stack/storage requirements, byte order and 31-bit addressing.
   Both profiles are ILP32 yet have different native service contracts.
4. Independently qualify MVS 3.8J linker/REXX/RecordSet path on ED209Z;
   separately qualify native z/OS31 load member and modern JES job run.
5. Obtain explicit permission for running custom executables, JES and native
   linkage on the modern z/OS host; preserve build/deployment logs and RCs.

IBM's public Z software trial FAQ says development is not allowed in the
standard hosted trials. The Lab's existing ED209C/ED209Z system is MVS 3.8J,
not licensed modern z/OS. Do not treat hosted trial availability as permission
for our custom builds. No modern z/OS execution allocation was confirmed in
the Library search as of 2026-10-15.

## SDK references and licensing

- <https://github.com/adesutherland/mainframe-elf-sdk/blob/main/docs/compiler/SDK.md>
- <https://github.com/adesutherland/mainframe-elf-sdk/blob/main/docs/RELEASE-PLAN.md>
- <https://github.com/adesutherland/mainframe-elf-sdk/blob/main/sdk/doc/INSTALLED-README.md>
- <https://early-access.ibm.com/software/support/trial/cst/welcomepage.wss?siteId=1658&tabId=4529&w=1>

Original SDK code is MIT; GCC, binutils, newlib, native tools and PDPCLIB
retain distinct original component notices. This spike links or vendors none
of their code. No SDK target runtime is represented as our MVS implementation.

## dev21 (2026-10-29): fail-closed SDK host-result contract

`run-sdk-host-smoke.py` now requires **the installed SDK 0.1.0's
`result.json`**, not merely a nonempty `.XMI`. Before reporting a host PASS
it verifies the exact one-profile receipt and compares:

- SDK manifest SHA-256 against the inspected installed manifest;
- copied C source SHA-256 against `z_backend_contract.c`;
- ELF image and native object-deck digests against their actual files;
- native XMIT digest, expected member `RXMVS24` or `RXMVS31`, and
  AMODE/RMODE (`24/24` or `31/ANY`);
- that expected output files are ordinary nonempty files, not symlinks.

The child process has a bounded timeout (`--timeout-sec`, default 900; maximum
3600). Existing output directories, missing SDK/source, overlapping paths,
invalid profiles and timeout failures are refused. An emitted
`oorexx-mvs-host-report.json` records the reason and always reports
`guest_executed=false`, `guest_return_code=null` and
`guest_qualified=false`.

The 23 isolated Python host contract controls passed in groups on 2026-10-29.
Python syntax and C99 host syntax checks also passed. All Python controls use a
**synthetic** installed SDK consumer; the downloaded GCC SDK, ELF exporter,
Classic Linker, XMIT restore, live MVS 3.8J and modern z/OS were **NOT_RUN**.
See [dev21 qualification evidence](../../evidence/dev21-elf-sdk-host-contract.md).
No increase from the inherited **190/199** cfront/cc370 units is claimed.
