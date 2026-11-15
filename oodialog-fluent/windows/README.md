# Windows native provider — build candidate

Architecture: Tom Dyer. Code: ChatGPT (GPT-6). Status: **BUILD CANDIDATE**.

`OodFluentIsland.cpp` is a native C++/WinRT DLL candidate targeting Microsoft Windows App SDK **2.6.5 stable**. It provides an HWND-hosted `DesktopWindowXamlSource`, creates genuine WinUI 3 `Button`, `ToggleSwitch`, `InfoBar` and `NumberBox` controls, and forwards their input to the native-independent `OodfSession` event queue. No Rexx handler runs inside a WinUI callback.

This DLL is **not** yet an installable ooDialog extension. The ooRexx native package glue, runtime test process, resource loading/geometry parity, keyboard focus handoff, UI Automation verification and per-control complete properties are still required. A Windows MSBuild compile is evidence of source compatibility only, not functional or visual qualification.

## Build

From a Visual Studio Developer Command Prompt with desktop C++ tooling and network access for NuGet:

```cmd
msbuild OodFluentWindows.vcxproj -restore -p:Configuration=Release -p:Platform=x64
```

The project pins `Microsoft.WindowsAppSDK` **2.6.5** and `Microsoft.Windows.CppWinRT` **3.0.260818.1**. Its `WindowsAppSdkBootstrapInitialize` is intentionally enabled in the DLL: stock ooDialog is an unpackaged program and does not automatically bootstrap the Windows App SDK runtime. Shipping the eventual extension requires the appropriate Windows App SDK runtime redistributable and a deployment manifest; never assume the development computer's NuGet cache is the runtime.

## API and responsibility

Open an `OodfSession` via `oodf_open`, create the island with `oodf_win_open(parentHwnd, session, &host)`, then add controls and geometry. Control events stay in the session until consumed with `oodf_poll`, preserving `resourceId`, `uid`, `handler`, `value`, `revision`. On dialog teardown, call `oodf_win_close` on the same UI thread, then `oodf_close`.

The API currently supports only a tiny, explicitly checked property subset. It does not claim that all 83 catalogue entries render. Unknown native control types return `E_NOTIMPL`; the catalogue marks experimental controls separately. A full release requires mapping all stable entries and parity tests.

### Gates still open

- Windows CI native DLL build success.
- Real Windows desktop `UserDialog` host attaches, shows all four controls, routes events to Rexx and exits without leaks.
- Focus bridge (`Tab`, Shift+Tab, accelerators), scaling/DPI, resize, recreation and modal lifecycle.
- Dispatcher queue shutdown ownership and COM apartment teardown for repeated multi-dialog use.
- Full native `OodFluentControl` Rexx proxy API, including resource ID and UIA properties.

References: [Microsoft XAML Islands](https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/host-controls-existing-desktop-apps), [Microsoft Windows App SDK unpackaged bootstrap](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/use-windows-app-sdk-run-time).
