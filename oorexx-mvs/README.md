# ooRexx interpreter port: MVS 3.8J and experimental z/OS targets

Experimental translation of the Open Object Rexx interpreter for IBM
System/370 / MVS 3.8J, with a **separate** Mainframe ELF SDK compiler
experiment for z/OS TSO31 and TSO24.

## Qualification snapshot — 23 October 2026

The accepted Linux-hosted core translation checkpoint is **190/199 permitted
ooRexx C++ units** reaching cfront C and `cc370 -S` nonempty assembler at
dev16. This is unchanged through the dev20 runtime/harness line.

The nine cfront-blocked files remain:
`NativeActivation.cpp`, `CommandIOConfiguration.cpp`, `Setup.cpp`,
`LibraryPackage.cpp`, `InternalPackage.cpp`, `Interpreter.cpp`,
`RexxUtilCommon.cpp`, `FileNative.cpp` and `StreamNative.cpp`.

There is **no complete MVS interpreter link, first ooRexx program on MVS,
full ooTest run or modern z/OS execution claim**. Some other Alchemy/MVS
components have run real JES jobs; their failures must not be counted as
successful ooRexx port execution.

## Where to start

- [LLM Gopher MVS sphere](sphere/README.md): evidence-scoped architecture,
  provenance, nine residuals, ABI/record contracts, guest observations and
  continuity/acceptance gates. Profile: `sphere/profiles/oo-rexx-mvs.json`.
- [Translation sources](TRANSLATION-SOURCES.md): full dev16 shell driver,
  cfront replacements, pinned-source verifier and dev13–dev16 transforms.
- [RecordSet adapter](port/mvs/MvsRecordProvider.h): native MVS QSAM/SVC99
  logical record semantics and retryable DD cleanup (separate dev11 dependency).
- [Unwind runtime](runtime/MvsUnwind.cpp): fail-closed single-task SJLJ
  bootstrap. Actual MVS setjmp/longjmp ABI remains unqualified.
- [ELF SDK experiment](experimental/elf-sdk/README.md): isolated C-only
  GCC16.2 SDK host packaging path for TSO31/TSO24. Not deployed to MVS 3.8J
  and not accepted as the primary backend.
- [Historical evidence](evidence/SOURCE-EVIDENCE.md): restored exact source
  matrices and [38-file archive](evidence/archive/README.md) of dev20
  qualification logs and checksums.

## Pinned source authority

- ooRexx: `de1db87f486d430d1faa9151b8a2d5f328ab70f2`
- cfront: `f87de66d9442230ba6fcbc965924a6a6dd31497e`
- cc370: `ddb1c8ccc7edd537373c924b761e15b703690565`
- Mainframe ELF SDK 0.1.0 release (2026-10-03), project
  [source](https://github.com/adesutherland/mainframe-elf-sdk).
  Upstream z/OS 1.5 selected TSO31 execution does not qualify this ooRexx port.
- Exact hashes of preserved dev20, RecordSet dev11 and experimental SDK
  delivery archives are in [sphere source authority](sphere/SOURCE_AUTHORITY.json).

## Host-only regression checks

With extracted RecordSet dev11 sources available as `RECORDSET_ROOT`:

```sh
bash tests/run-recordset-host.sh "$RECORDSET_ROOT"
bash tests/run-unwind-host.sh
bash tests/run-dev20-guard.sh
python3 -m unittest discover -s tests -p 'test_dev*.py' -q
cd experimental/elf-sdk
python3 -m unittest discover -s tests -p 'test*.py' -q
cc -std=c99 -Wall -Wextra -Werror -pedantic -fsyntax-only z_backend_contract.c
```

Sphere structure can be checked with:

```sh
python3 sphere/tests/verify_sphere.py
```

All are **host-level** gates. None replace a source-pinned cfront/cc370
rerun, an MVS IEWL/JES test, or a permitted modern z/OS31 load-module run.

The existing MVS3.8J guest ED209Z on host ED209C is distinct from ED209ZZ
on host ED209I. Use approved remote management procedures. Nothing in this
repository authorizes access to a modern z/OS host.
