# ooDialog Fluent Controls: current qualification

Architecture: Tom Dyer. Code: ChatGPT (GPT-6). Updated 2026-11-15.

Project lane: `oodialog_fluent_controls` (Rasen Falcon). Source: `animatedads/oorexx`, branch `feature/oodialog-fluent-controls-20261115`, path `oodialog-fluent/`.

## What exists

- 83 named Windows UI controls, layouts and system features in one machine-checked catalogue. `availability=stable` means Microsoft WinUI API availability **only**.
- Native-independent C++17 model preserving resource ID plus occurrence UID, strongly checked control properties and handlers, deterministic event queue and removal.
- C ABI `oodf_*` for the future native ooRexx binding and Windows XAML Island DLL. Buffer-too-small does not drop an event.
- Executable test suite; `sh tests/run_tests.sh`. CMake/CTest and Ubuntu/Windows CI workflow candidates.
- Windows x64 C++/WinRT native provider DLL **prior BUILD_PASS** (GitHub CI run 43719132986), with HWND-hosted WinUI 3 island and four control creation paths.
- **New unqualified bridge candidate**: `windows/OodFluentRexx.cpp` exports the ooRexx `RexxGetPackage` routine table from the provider DLL; `rexx/OodFluent.cls` provides `.OodFluentHost` and `.OodFluentControl` compatible proxies. Native functions accept ooDialog's 0x-prefixed HWND and tokenised session/occurrence identities. The owner UI thread explicitly drains events into dialog methods.
- **New runtime probe**: `windows/OodFluentSmoke.cpp` creates a real Win32 HWND, XAML island, four controls, changes properties and tears them down. Windows CI attempts it as a separately recorded probe; headless CI limitations must not become a false PASS.

## What does not exist

- No Windows desktop **runtime PASS** for the island inside a running ooDialog process; no demonstrated visual or callback behavior.
- New Rexx/WinUI bridge package has **not yet completed Windows CI compilation or a live loading test**. It is a candidate, not a released component.
- No Windows `UserDialog`, `ResDialog`, `RcDialog` runtime parity qualification.
- No claim of native control coverage, 100% migration or deployed release.

## Continuation instructions

Read `docs/WINDOWS_HOST_CONTRACT.md`, `windows/README.md` and the upstream `DialogControls.cls`/`oodialog.dll` package entry first. Compile the separate WinUI host DLL against Windows App SDK 2.6.5 and qualify Button, ToggleSwitch, InfoBar and NumberBox as a real Windows proof before adding control families. Bind ooRexx objects to the C ABI, with no hand-coded Python orchestration and no changes to the other lanes' files.

Old ooDialog runs unchanged; Linux/Qt6, browser/WASM and Wire follow their own authority boundaries. The Designer may import this catalogue after its owner agrees the extension seam; preserving resource ID, UID and event names is mandatory. Experimental WinUI controls must be gated.

Evidence: core tests LOCAL_PASS 88/88, GitHub Windows+Ubuntu core test PASS; previous Windows DLL BUILD_PASS. New package/GUI smoke changes are awaiting CI. Until a Windows desktop run with ooRexx handlers and user-visible events passes, visual readiness is **NOT QUALIFIED**.
