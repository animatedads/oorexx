# ooDialog Fluent Controls: current qualification

Architecture: Tom Dyer. Code: ChatGPT (GPT-6). Updated 2026-11-15.

Project lane: `oodialog_fluent_controls` (Rasen Falcon). Source: `animatedads/oorexx`, branch `feature/oodialog-fluent-controls-20261115`, path `oodialog-fluent/`.

## What exists

- 83 named Windows UI controls, layouts and system features in one machine-checked catalogue. `availability=stable` means Microsoft WinUI API availability **only**.
- Native-independent C++17 model preserving resource ID plus occurrence UID, strongly checked control properties and handlers, deterministic event queue and removal.
- C ABI `oodf_*` for the future native ooRexx binding and Windows XAML Island DLL. Buffer-too-small does not drop an event.
- Executable test suite; `sh tests/run_tests.sh`. CMake/CTest and Ubuntu/Windows CI workflow candidates.
- Windows x64 C++/WinRT native provider and native ooRexx package DLL **BUILD_PASS** (GitHub CI run 43724613822); four real control creation paths.
- **Unqualified ooDialog bridge candidate**: `windows/OodFluentRexx.cpp` exports the ooRexx `RexxGetPackage` routine table from the provider DLL; `rexx/OodFluent.cls` provides `.OodFluentHost` and `.OodFluentControl` compatible proxies. Native functions accept ooDialog's 0x-prefixed HWND and tokenised session/occurrence identities. The owner UI thread explicitly drains events into dialog methods.
- **Windows HWND runtime probe**: `windows/OodFluentSmoke.cpp` creates a real Win32 HWND and XAML island, and verifies creation, property updates, native message pump and teardown separately by control family. Empty, Button and ToggleSwitch are exit=0, including proper close (run 43724613822). InfoBar and NumberBox create/update in diagnostic mode but crash at `DesktopWindowXamlSource.Close`, exit `0xC0000005`. Both are **refused by default with `E_NOTIMPL`**; `OODF_ALLOW_UNQUALIFIED_NATIVE=1` is for isolated testing only.
- **Native crash evidence**: CI run 43724613822 contains 134,631-byte minidump and cdb symbolic call stack. Fault at `Microsoft_UI_Xaml!ComPtr<IContentIsland>::As<IContentIslandExperimental>+0x18` (null), called by `DirectUI::XamlIsland::Close+0x195` then `DesktopWindowXamlSource::Close+0x102`. Retaining controls, clearing focus and closing InfoBar first did not repair it; CI run 43725003804 additionally shows explicit unload and 40 dispatcher turns also fail. CI now requires the safe-mode runtime subset to pass and reports unsafe-control crashes separately; a green badge is **not** full runtime PASS for all 83 catalogue targets.
- **Stable authored UID**: new `Session::createWithUid`, `oodf_create_authored`, `oodf_win_add_authored`, and `OodfNativeCreateAuthored` maintain authored occurrence UID across backend recreation/reopen; duplicates and zero are rejected. Dynamic controls retain a noncolliding auto UID. 101/101 local native-independent checks.

## What does not exist

- No Windows desktop **runtime PASS** for the island inside a running ooDialog process; no demonstrated visual or callback behavior, and complex-control shutdown is not safe.
- New Rexx/WinUI bridge package **has completed Windows CI compilation but not a live ooRexx package-loading test**. It is a candidate, not a released component.
- No Windows `UserDialog`, `ResDialog`, `RcDialog` runtime parity qualification.
- No claim of native control coverage, 100% migration or deployed release.

## Continuation instructions

Read `docs/WINDOWS_HOST_CONTRACT.md`, `windows/README.md` and the upstream `DialogControls.cls`/`oodialog.dll` package entry first. Compile the separate WinUI host DLL against Windows App SDK 2.6.5 and qualify Button, ToggleSwitch, InfoBar and NumberBox as a real Windows proof before adding control families. Bind ooRexx objects to the C ABI, with no hand-coded Python orchestration and no changes to the other lanes' files.

**Qt6 lane review REQ-00003661**: keep all Rexx proxy classes prefixed (`.OodFluent*`) and do not subclass upstream `DialogControl`; `connectEvent` is local to these proxies. Authored UID support is now implemented in the model and native APIs, but namespace collisions across renderer providers and long-lived IDs remain a parity test. Define typed complex property codecs before implementing list/date/color control families. A portable Rexx provider seam for WinUI, Qt6 and Web is under design, not a claim of Linux WinUI availability. The overlap between `oodialog_linux` and Claude's native `oodialog-qt6-v0.7` remains an owner/architecture decision; do not claim either lane merged.

Old ooDialog runs unchanged; Linux/Qt6, browser/WASM and Wire follow their own authority boundaries. The Designer may import this catalogue after its owner agrees the extension seam; preserving resource ID, UID and event names is mandatory. Experimental WinUI controls must be gated.

Evidence: core tests LOCAL_PASS 101/101, GitHub Windows+Ubuntu core test PASS; current Windows DLL and native ooRexx package BUILD_PASS. Native HWND runtime for Button and ToggleSwitch passes through teardown, but InfoBar and NumberBox crash in the diagnostic opt-in and are disabled by default. Until the full control set closes safely and a Windows desktop run with ooRexx handlers and user-visible events passes, visual readiness is **NOT QUALIFIED**.
