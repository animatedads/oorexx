# Windows native provider and ooRexx bridge — qualification candidate

Architecture: Tom Dyer. Code: ChatGPT (GPT-6). Status: **prior Windows DLL BUILD_PASS; new ooRexx bridge pending Windows CI; runtime not yet qualified**.

`OodFluentIsland.cpp` is a native C++/WinRT DLL candidate targeting Microsoft Windows App SDK **2.6.5 stable**. It provides an HWND-hosted `DesktopWindowXamlSource`, creates genuine WinUI 3 `Button`, `ToggleSwitch`, `InfoBar` and `NumberBox` controls, and forwards their input to the native-independent `OodfSession` event queue. No Rexx handler runs inside a WinUI callback.

Windows CI run [43719132986](https://github.com/animatedads/oorexx/actions/runs/43719132986) built the earlier x64 DLL with 0 warnings and 0 errors. The current increment adds `OodFluentRexx.cpp`, `rexx/OodFluent.cls`, and `OodFluentSmoke.cpp`; those additions have not yet qualified as a live ooDialog integration. Resource loading/geometry parity, keyboard focus handoff, UI Automation verification, and per-control complete properties remain open. An MSBuild compile is evidence of source compatibility only, not functional or visual qualification.

## Build

From a Visual Studio Developer Command Prompt with desktop C++ tooling and network access for NuGet:

```cmd
msbuild OodFluentWindows.vcxproj -restore -p:Configuration=Release -p:Platform=x64
```

The project pins `Microsoft.WindowsAppSDK` **2.6.5** and `Microsoft.Windows.CppWinRT` **3.0.260818.1**. It compiles the native ooRexx package with official headers from `ooRexx/ooRexx` commit `c12e988dc3708846592e20b48350bcdef5b19c60`, in `vendor/oorexx-api/api` (or set MSBuild property `OOREXX_API_DIR`). Both `api` and `api/platform/windows` are required include paths for `rexxapitypes.h`. CI checks out these pinned headers, rather than vendoring them into this tree. Its `WindowsAppSdkBootstrapInitialize` is intentionally enabled in the DLL: stock ooDialog is an unpackaged program and does not automatically bootstrap the Windows App SDK runtime. Shipping requires the Windows App SDK runtime redistributable and a deployment manifest; never assume the development computer's NuGet cache is the runtime.

## ooRexx calling surface

Copy `OodFluentWindows.dll` and `OodFluent.cls` into the ooRexx library/path search locations (or configure the package path) and use the class from an *existing* ooDialog method:

```rexx
/* Inside an ooDialog instance; full GUI demo integration remains pending. */
fluent = .OodFluentHost~attach(self, 'C:\\catalogue\\controls.tsv')
fluent~move(8, 8, 480, 260)
save = fluent~newButton(1001, 'Save')
save~connectEvent('click', 'onFluentSave')
status = fluent~newInfoBar(1002, 'Ready')
/* Called periodically from the ooDialog UI-thread's event dispatch: */
fluent~dispatchPending
/* In the dialog teardown method, on the same thread: */
fluent~close
```

The dialog event callback `onFluentSave(resourceId, uid, eventValue)` is executed only while the ooDialog thread calls `dispatchPending`; the initial WinUI callback merely queues an event. `pollEvent` returns a Directory containing `RESOURCEID`, `UID`, `REVISION`, `NAME`, `VALUE`, `HANDLER`, or `.nil` if empty. `dispatchPending(limit)` defaults to 64 events to bound processing on a busy UI thread. Existing ooDialog controls and their resource IDs are not replaced. The WinUI host has separate occurrence UIDs so repeated Windows static resource IDs are safe.

This is an **explicit-pump preview**, not automatic ooDialog `WM_NOTIFY` routing. Focus/keyboard bridging and timer-message integration still require testing. Call `close` before the HWND is destroyed; do not rely on garbage collection to tear down XAML objects on the correct UI thread. The four implemented control types only support the documented subset in `OodFluentIsland.cpp`.

`OodFluentSmoke.exe` can attempt a real HWND + island lifecycle in an interactive desktop session and return a nonzero exit code on failure. GitHub hosted Windows runners may lack a usable interactive desktop; CI deliberately records the runtime result separately from compilation and preserves its diagnostic log. A green workflow alone **does not prove** a live ooDialog run.

## API and responsibility

Open an `OodfSession` via `oodf_open`, create the island with `oodf_win_open(parentHwnd, session, &host)`, then add controls and geometry. Control events stay in the session until consumed with `oodf_poll`, preserving `resourceId`, `uid`, `handler`, `value`, `revision`. On dialog teardown, call `oodf_win_close` on the same UI thread, then `oodf_close`.

The API currently supports only a tiny, explicitly checked property subset. It does not claim that all 83 catalogue entries render. Unknown native control types return `E_NOTIMPL`; the catalogue marks experimental controls separately. A full release requires mapping all stable entries and parity tests.

### Gates still open

- Windows CI native DLL build success.
- Real Windows desktop `UserDialog` host attaches, shows all four controls, routes events to Rexx and exits without leaks. The smoke harness is native Win32, not an ooDialog process.
- Focus bridge (`Tab`, Shift+Tab, accelerators), scaling/DPI, resize, recreation and modal lifecycle.
- Dispatcher queue shutdown ownership and COM apartment teardown for repeated multi-dialog use.
- Full native `OodFluentControl` Rexx proxy API, including resource ID and UIA properties.

References: [Microsoft XAML Islands](https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/host-controls-existing-desktop-apps), [Microsoft Windows App SDK unpackaged bootstrap](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/use-windows-app-sdk-run-time).
