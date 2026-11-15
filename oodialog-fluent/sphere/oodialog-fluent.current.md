# ooDialog Fluent Controls: current qualification

Architecture: Tom Dyer. Code: ChatGPT (GPT-6). Updated 2026-11-15.

Project lane: `oodialog_fluent_controls` (Rasen Falcon). Source: `animatedads/oorexx`, branch `feature/oodialog-fluent-controls-20261115`, path `oodialog-fluent/`.

## What exists

- 83 named Windows UI controls, layouts and system features in one machine-checked catalogue. `availability=stable` means Microsoft WinUI API availability **only**.
- Native-independent C++17 model preserving resource ID plus occurrence UID, strongly checked control properties and handlers, deterministic event queue and removal.
- C ABI `oodf_*` for the future native ooRexx binding and Windows XAML Island DLL. Buffer-too-small does not drop an event.
- Executable test suite; `sh tests/run_tests.sh`. CMake/CTest and Ubuntu/Windows CI workflow candidates.

## What does not exist

- Windows x64 native C++/WinRT DLL **BUILD_PASS** (GitHub CI run 43718942362, 0 warnings / 0 errors), with an HWND-hosted WinUI 3 island and creation paths for four actual Windows controls at `windows/OodFluentIsland.cpp`. It has not been exercised inside a running ooDialog process.
- No `.OodFluentHost` Rexx classes or native ooRexx package registration.
- No Windows `UserDialog`, `ResDialog`, `RcDialog` runtime parity qualification.
- No claim of native control coverage, 100% migration or deployed release.

## Continuation instructions

Read `docs/WINDOWS_HOST_CONTRACT.md`, `windows/README.md` and the upstream `DialogControls.cls`/`oodialog.dll` package entry first. Compile the separate WinUI host DLL against Windows App SDK 2.6.5 and qualify Button, ToggleSwitch, InfoBar and NumberBox as a real Windows proof before adding control families. Bind ooRexx objects to the C ABI, with no hand-coded Python orchestration and no changes to the other lanes' files.

Old ooDialog runs unchanged; Linux/Qt6, browser/WASM and Wire follow their own authority boundaries. The Designer may import this catalogue after its owner agrees the extension seam; preserving resource ID, UID and event names is mandatory. Experimental WinUI controls must be gated.

Evidence: v0.1 core tests LOCAL_PASS 88/88, GitHub Windows+Ubuntu core test PASS; Windows DLL BUILD_PASS. Until a Windows desktop run with ooRexx handlers and user-visible events passes, visual readiness is **NOT QUALIFIED**.
