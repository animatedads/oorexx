# ooRexx MVS 3.8J port — dev18

Experimental port of the Open Object Rexx interpreter to IBM S/370 and classic MVS 3.8J.

## Current status (10 October 2026)

**190/199 permitted core translation units** were reported to pass the Linux-hosted C++ shadow -> AT&T cfront C -> cc370 -S -> non-empty S/370 assembler pipeline at dev16. dev17 and dev18 strengthen host-tested unwind and MVS native-record adapter semantics, but **do not increase** the 190/199 translation count.

Nine translation blockers remain:
- `NativeActivation.cpp`
- `CommandIOConfiguration.cpp`
- `Setup.cpp`
- `LibraryPackage.cpp`
- `InternalPackage.cpp`
- `Interpreter.cpp`
- `RexxUtilCommon.cpp`
- `FileNative.cpp`
- `StreamNative.cpp`

**No complete MVS link, JES execution, or ooTest conformance is claimed.** Producing S/370 assembler is not equivalent to a running ooRexx interpreter.

## Provenance

- Upstream: https://github.com/ooRexx/ooRexx
- Pinned ooRexx commit: `de1db87f486d430d1faa9151b8a2d5f328ab70f2`
- Full dev18 delivery archive: `oorexx-mvs24-cfront-bulk-dev18.zip`
- Dev18 archive SHA-256: `ae64882eabb7645937d6c2d73343721562b20e020377eef4abebe77bed72c1db`
- Original source-oriented GitHub snapshot: `oorexx-mvs-github-ready-dev18.zip`
- RecordSet v0.1-dev11 is a separate dependency and is not vendored.

## Implementation boundary

- Native MVS dataset support uses logical records and the independently developed RecordSet QSAM/SVC 99 interface. It is not a substitute for POSIX byte streams or an implementation of full ooRexx stream semantics.
- MVS unwind uses an SJLJ bootstrap. Unmatched activation transfers fail closed; real MVS ABI and reentrancy qualification remain outstanding.
- Keep the remaining nine translation units visible until rechecked with the pinned toolchain. Do not claim a translation result from host-only adapter tests.
- Preserve all upstream ooRexx licensing and notices.

## Delivery and tests

The validated dev18 source-oriented delivery comprises 70 files of source transformations, patched cfront material, adapters, tests, scripts and evidence. The bootstrap commit establishes this directory and records exact checkpoint provenance. Do not mistake an incomplete repository sync for a complete source snapshot.

The relevant qualification evidence remains host-side only. Real MVS execution will be tracked separately when JES output is available.
