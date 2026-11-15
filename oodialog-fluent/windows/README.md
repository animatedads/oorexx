# Windows native provider and ooRexx bridge — qualification candidate

Architecture: Tom Dyer. Code: ChatGPT (GPT-6). Status: **Windows DLL and native ooRexx bridge BUILD_PASS; limited native HWND runtime PASS; real ooDialog runtime pending**.

`OodFluentIsland.cpp` is a native C++/WinRT DLL candidate targeting Microsoft Windows App SDK **2.6.5 stable**. It provides an HWND-hosted `DesktopWindowXamlSource`, creates genuine WinUI 3 `Button`, `ToggleSwitch`, `InfoBar` and `NumberBox` controls, and forwards their input to the native-independent `OodfSession` event queue. No Rexx handler runs inside a WinUI callback.

Windows CI [43724613822](https://github.com/animatedads/oorexx/actions/runs/43724613822) built the x64 DLL, native ooRexx package and HWND smoke exercise. The independent C++ model passed on both Windows and Ubuntu. A Win32 HWND plus XAML island and `Button` and `ToggleSwitch` each opened, applied properties, pumped native messages and closed with process exit 0. Both `InfoBar` and `NumberBox` can be created and updated with a diagnostic opt-in, but each independently crashes when `DesktopWindowXamlSource.Close()` executes. **Both are rejected with `E_NOTIMPL` by default** while this is unresolved; set `OODF_ALLOW_UNQUALIFIED_NATIVE=1` only in isolated crash probes. These additions have not yet qualified as a live ooDialog integration. Resource loading/geometry parity, keyboard focus handoff, UI Automation verification, and per-control complete properties remain open.

## Build

From a Visual Studio Developer Command Prompt with desktop C++ tooling and network access for NuGet:

```cmd
msbuild OodFluentWindows.vcxproj -restore -p:Configuration=Release -p:Platform=x64
```

The project pins `Microsoft.WindowsAppSDK` **2.6.5** and `Microsoft.Windows.CppWinRT` **3.0.260818.1**. It compiles the native ooRexx package with official headers from `ooRexx/ooRexx` commit `c12e988dc3708846592e20b48350bcdef5b19c60`, in `vendor/oorexx-api/api` (or set MSBuild property `OOREXX_API_DIR`). Both `api` and `api/platform/windows` are required include paths for `rexxapitypes.h`. CI checks out these pinned headers, rather than vendoring them into this tree.

Runtime startup: The prior DLL used `WindowsAppSdkBootstrapInitialize=true`. Its Windows CI smoke produced no `MAIN_ENTER` trace and hung before the executable's entry point, consistent with a loader/auto-initializer problem (diagnosis, not yet proven cause). The current project disables auto-init in the DLL and explicitly calls `MddBootstrapInitialize` **after** initializing the dialog COM STA and before any WinUI calls. A process-wide scoped reference count balances `MddBootstrapShutdown` after the final island closes. This follows the [Microsoft unpackaged-app bootstrap contract](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/use-windows-app-sdk-run-time). Shipping still requires the Windows App SDK runtime redistributable and deployment manifest; never assume the development computer's NuGet cache is the runtime.

## ooRexx calling surface

Copy `OodFluentWindows.dll` and `OodFluent.cls` into the ooRexx library/path search locations (or configure the package path) and use the class from an *existing* ooDialog method:

```rexx
/* Inside an ooDialog instance; full GUI demo integration remains pending. */
fluent = .OodFluentHost~attach(self, 'C:\\catalogue\\controls.tsv')
fluent~move(8, 8, 480, 260)
/* Optional third argument is an authored occurrence UID from the Designer. */
save = fluent~newButton(1001, 'Save', 71001)
save~connectEvent('click', 'onFluentSave')
mode = fluent~newToggleSwitch(1002, 'Dark mode')
mode~setOn(.true)
/* Called periodically from the ooDialog UI-thread's event dispatch: */
fluent~dispatchPending
/* In the dialog teardown method, on the same thread: */
fluent~close
```

The dialog event callback `onFluentSave(resourceId, uid, eventValue)` is executed only while the ooDialog thread calls `dispatchPending`; the initial WinUI callback merely queues an event. `pollEvent` returns a Directory containing `RESOURCEID`, `UID`, `REVISION`, `NAME`, `VALUE`, `HANDLER`, or `.nil` if empty. `dispatchPending(limit)` defaults to 64 events to bound processing on a busy UI thread. Existing ooDialog controls and their resource IDs are not replaced. The authored occurrence UID survives different backends/reopens and is distinct from a Windows resource ID. A UID cannot be reassigned in the same native session, even after removing its old control; for dynamically created controls, the host assigns a session-local UID. `uid=0` is invalid.

This is an **explicit-pump preview**, not automatic ooDialog `WM_NOTIFY` routing. Focus/keyboard bridging and timer-message integration still require testing. Call `close` before the HWND is destroyed; do not rely on garbage collection to tear down XAML objects on the correct UI thread. The four implemented control types only support the documented subset in `OodFluentIsland.cpp`.

`OodFluentSmoke.exe` can attempt a real HWND + island lifecycle in an interactive desktop session and return a nonzero exit code on failure. GitHub hosted Windows runners may lack a usable interactive desktop; CI deliberately records the runtime result separately from compilation and preserves its diagnostic log. A green workflow alone **does not prove** a live ooDialog run.

CI run 43722647566 first demonstrated executable entry, `OodfSession` opening, a real HWND and entry to `oodf_win_open`. The provider returned `0x80670016` until the Microsoft-signed Windows App Runtime 2.6.5 x64 installer was applied to the ephemeral runner. That install now succeeds. CI run 43724613822 isolated the remaining crash: `empty`, `button`, `toggle` exit 0; `info`, `number`, `no-number`, `all` exit `0xC0000005` during island close. Retaining the complex controls through `Close()` or clearing focus and closing InfoBar first does not resolve it. A Windows minidump analysed with Microsoft's installed `cdb.exe` shows a null pointer inside `Microsoft_UI_Xaml!Microsoft::WRL::ComPtr<IContentIsland>::As<IContentIslandExperimental>`, reached from `DirectUI::XamlIsland::Close+0x195` and `DesktopWindowXamlSource::Close+0x102`. CI run [43725003804](https://github.com/animatedads/oorexx/actions/runs/43725003804) shows explicitly removing the complex templated controls before closing, with or without another 40 message-pump cycles, also fails. This is a reproducible native Windows App SDK shutdown fault in this host setup, not proof of any particular root cause in the Microsoft runtime. The provider now blocks these two known-crashing paths by default. A successful CI installation or HWND smoke is not a user-machine deployment or ooDialog event-parity claim.

## API and responsibility

Open an `OodfSession` via `oodf_open`, create the island with `oodf_win_open(parentHwnd, session, &host)`, then add controls and geometry. Control events stay in the session until consumed with `oodf_poll`, preserving `resourceId`, `uid`, `handler`, `value`, `revision`. On dialog teardown, call `oodf_win_close` on the same UI thread, then `oodf_close`.

The API currently supports only a tiny, explicitly checked property subset. It does not claim that all 83 catalogue entries render. Unknown native control types return `E_NOTIMPL`; the catalogue marks experimental controls separately. A full release requires mapping all stable entries and parity tests.

### Gates still open

- Windows CI native DLL build success (achieved); complex-control shutdown safety (open).
- Real Windows desktop `UserDialog` host attaches, shows all four controls, routes events to Rexx and exits without leaks. The smoke harness is native Win32, not an ooDialog process.
- Focus bridge (`Tab`, Shift+Tab, accelerators), scaling/DPI, resize, recreation and modal lifecycle.
- Dispatcher queue shutdown ownership and COM apartment teardown for repeated multi-dialog use.
- Full native `OodFluentControl` Rexx proxy API, including resource ID and UIA properties.

References: [Microsoft XAML Islands](https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/host-controls-existing-desktop-apps), [Microsoft Windows App SDK unpackaged bootstrap](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/use-windows-app-sdk-run-time).
