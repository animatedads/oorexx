# Windows native provider and ooRexx bridge — qualification candidate

Architecture: Tom Dyer. Code: ChatGPT (GPT-6). Status: **Windows DLL/native ooRexx BUILD_PASS; five native HWND controls pass individually and together; real ooRexx `UserDialog` creates all five, dispatches four property-triggered native events and closes PASS 3/3 behind diagnostic cross-thread opt-in**.

`OodFluentIsland.cpp` is a native C++/WinRT DLL candidate targeting Microsoft Windows App SDK **2.6.5 stable**. It provides an HWND-hosted `DesktopWindowXamlSource`, creates genuine WinUI 3 `Button`, `ToggleSwitch`, `CheckBox`, `ToggleButton`, `Slider`, `TextBox`, `ProgressBar`, `InfoBar` and `NumberBox` controls, and forwards their input to the native-independent `OodfSession` event queue. No Rexx handler runs inside a WinUI callback. **Only the first five are allowed by default**: the four others are known to crash this island at shutdown and require explicit diagnostic opt-in.

Windows CI [44518725960](https://github.com/animatedads/oorexx/actions/runs/44518725960) builds the x64 DLL/native ooRexx package and runs both separate and combined HWND island tests. `Button`, `ToggleSwitch`, `CheckBox`, `ToggleButton` and `Slider` each opened, applied properties, pumped messages, removed their controls and closed with process exit 0, including all five in one island. The C++ model and C ABI passed **1315/1315** independent checks on both Windows and Ubuntu. The ABI protects event queues and retries across HWND/Rexx threads. In the same green run, **three independent ooRexx 5.2.0 `UserDialog` processes** each created all five, demonstrated an automatic UID `U9223372036854775808` followed by authored UID `U1`, delivered four revision-aware property-driven native events to Rexx handlers and closed with exit code 0 (`REXX_PROBE_PASS=3/3`). It uses the opt-in `OODF_TEST_CROSS_THREAD_HOOK=1` broker, not yet a release-default interface. `InfoBar`, `NumberBox`, `TextBox` and `ProgressBar` can be created and updated with a separate diagnostic opt-in, but each crashes during `DesktopWindowXamlSource.Close()`. **All four return `E_NOTIMPL` by default**. Resource loading, keyboard focus handoff, UI Automation, physical user input events and full property coverage remain open.

## Build

From a Visual Studio Developer Command Prompt with desktop C++ tooling and network access for NuGet:

```cmd
msbuild OodFluentWindows.vcxproj -restore -p:Configuration=Release -p:Platform=x64
```

The project pins `Microsoft.WindowsAppSDK` **2.6.5** and `Microsoft.Windows.CppWinRT` **3.0.260818.1**. It compiles the native ooRexx package with official headers from `ooRexx/ooRexx` commit `c12e988dc3708846592e20b48350bcdef5b19c60`, in `vendor/oorexx-api/api` (or set MSBuild property `OOREXX_API_DIR`). Both `api` and `api/platform/windows` are required include paths for `rexxapitypes.h`. CI checks out these pinned headers, rather than vendoring them into this tree.

Runtime startup: The prior DLL used `WindowsAppSdkBootstrapInitialize=true`. Its Windows CI smoke produced no `MAIN_ENTER` trace and hung before the executable's entry point, consistent with a loader/auto-initializer problem (diagnosis, not yet proven cause). The current project disables auto-init in the DLL and explicitly calls `MddBootstrapInitialize` **after** initializing the dialog COM STA and before any WinUI calls. A process-wide scoped reference count balances `MddBootstrapShutdown` after the final island closes. This follows the [Microsoft unpackaged-app bootstrap contract](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/use-windows-app-sdk-run-time). Shipping still requires the Windows App SDK runtime redistributable and deployment manifest; never assume the development computer's NuGet cache is the runtime.

## ooRexx calling surface

Copy `OodFluentWindows.dll` (native ooRexx package entry `OodFluentRexx`) and `OodFluent.cls` (defines `.OodFluentHost` and `.OodFluentControl`) into the ooRexx library/path search locations (or configure the package path) and use the class from an *existing* ooDialog method:

```rexx
/* Inside an existing ooDialog instance; native bridge preview. */
/* ::requires 'ooDialog.cls' and ::requires 'OodFluent.cls' in the program. */
fluent = .OodFluentHost~attach(self, 'C:\\catalogue\\controls.tsv')
fluent~move(8, 8, 480, 260)
/* Optional third argument is an authored occurrence UID from the Designer. */
save = fluent~newButton(1001, 'Save', 71001)
save~connectEvent('click', 'onFluentSave')
mode = fluent~newToggleSwitch(1002, 'Dark mode')
mode~setOn(.true)
accept = fluent~newCheckBox(1003, 'Accept')
accept~setChecked(.true)
pin = fluent~newToggleButton(1004, 'Pin')
value = fluent~newSlider(1005, 'Level')
value~setValue(42.5)
/* Called from an ooDialog/Rexx dispatch point, never a XAML delegate: */
fluent~dispatchPendingVersioned
/* Close before the ooDialog HWND is destroyed: */
fluent~close
```

The dialog event callback is executed only while the ooDialog thread dispatches pending events; the initial WinUI callback merely queues an event. `pollEvent` returns a Directory containing `RESOURCEID`, `UID`, `REVISION`, `NAME`, `VALUE`, `HANDLER`, or `.nil` if empty. `dispatchPending(limit)` defaults to 64 events and keeps the original handler shape `(resourceId, uid, eventValue)`. `dispatchPendingVersioned(limit)` (or `dispatchPending(limit, .true)`) opts into `(resourceId, uid, eventValue, revision)`; use a four-argument Rexx handler with that form. Synchronously emitted property-driven XAML callbacks are queued **after** the model property revision advances. Existing ooDialog controls and their resource IDs are not replaced. Authored occurrence identities occupy native unsigned 64-bit values **1 through 2^63−1** and survive different backends/reopens; automatically assigned identities start at **2^63** and remain session-local. The Rexx package represents them as opaque `U`-prefixed string tokens (`U1`, `U9223372036854775808`) to avoid decimal rounding under Rexx default `NUMERIC DIGITS 9`; do not convert these tokens into numeric values. The bridge temporarily also accepts bare decimal input identities for migration. A UID cannot be reassigned in the same native session, even after removing its old control; `uid=0` and authored UIDs in the automatic range are invalid. Designer text-token canonicalization and cross-lifetime reuse/generation semantics are **still open**, not silently specified by this split.

This is an **explicit-pump preview**, not automatic ooDialog `WM_NOTIFY` routing. Focus/keyboard bridging and timer-message integration still require testing. Call `close` before the HWND is destroyed; do not rely on garbage collection to tear down XAML objects on the correct UI thread. In a real ooDialog the Rexx `initDialog` activity is on a **different thread from the dialog HWND**. `OodFluentRexx.cpp` includes an experimental same-process GUI-thread broker using a thread-specific `WH_CALLWNDPROC` hook and synchronous requests. It passes the initial `UserDialog` lifecycle test, but is restricted to `OODF_TEST_CROSS_THREAD_HOOK=1` until timeout/cancellation, thread shutdown, reentrancy and event-parity tests are complete. By default a cross-thread attach returns `RPC_E_WRONG_THREAD`. The five supported native control types only support the subset in `OodFluentIsland.cpp`.

`OodFluentSmoke.exe` exercises the native HWND lifecycle. `rexx/FluentUserDialogSmoke.rex` uses the official portable ooRexx 5.2.0 runtime (verified ZIP SHA-256 `d7ea5b40f0f889d0b307bbc217fe9fb36bc3e3fd0688a829668ce681a350203e`), loads the native package, creates a genuine `UserDialog`, builds five WinUI controls, changes properties, binds four native event kinds to Rexx instance methods, and closes using the documented `endAsyncExecution` join. A **three-process live-Rexx trial** is mandatory in CI. It does not prove mouse, keyboard, visual appearance, accessibility, or physical user-originated events. The real-ooDialog probe is a **required CI step**; the hook is still diagnostic-only at runtime.

CI run 43722647566 first demonstrated executable entry, `OodfSession` opening, a real HWND and entry to `oodf_win_open`. The provider returned `0x80670016` until the Microsoft-signed Windows App Runtime 2.6.5 x64 installer was applied to the ephemeral runner. That install now succeeds. CI run 43724613822 isolated `InfoBar`/`NumberBox` island-close crashes. Retaining the complex controls through `Close()` or clearing focus and closing InfoBar first does not resolve it. A Windows minidump analysed with Microsoft's installed `cdb.exe` shows a null pointer inside `Microsoft_UI_Xaml!Microsoft::WRL::ComPtr<IContentIsland>::As<IContentIslandExperimental>`, reached from `DirectUI::XamlIsland::Close+0x195` and `DesktopWindowXamlSource::Close+0x102`. CI run [43725003804](https://github.com/animatedads/oorexx/actions/runs/43725003804) shows explicitly removing the complex controls before closing, with or without another 40 message-pump cycles, also fails. New CI [43761232423](https://github.com/animatedads/oorexx/actions/runs/43761232423) separately observes the same close-stage `0xC0000005` with `TextBox` and `ProgressBar`. This is a reproducible native Windows App SDK shutdown fault in this host setup, **not** proof of any particular Microsoft runtime root cause. The provider now blocks all four known-crashing paths by default. A successful CI installation or HWND smoke is not a user-machine deployment or ooDialog event-parity claim.

## API and responsibility

Open an `OodfSession` via `oodf_open`, create the island with `oodf_win_open(parentHwnd, session, &host)`, then add controls and geometry. Control events stay in the session until consumed with `oodf_poll`, preserving `resourceId`, `uid`, `handler`, `value`, `revision`. On dialog teardown, call `oodf_win_close` on the same UI thread, then `oodf_close`.

The API currently supports only a tiny, explicitly checked property subset. It does not claim that all 83 catalogue entries render. Unknown native control types return `E_NOTIMPL`; the catalogue marks experimental controls separately. A full release requires mapping all stable entries and parity tests.

### Gates still open

- Windows CI native DLL build success (achieved); complex-control shutdown safety (open).
- Real `UserDialog` native attach/create/update/close of five controls and four property-triggered Rexx events achieved 3/3 in diagnostic mode, now a mandatory CI gate. Still pending: physical input-driven Rexx events, visual UIA checks, the other 78 catalogue targets, resource dialogs, independent UI-thread-broker safety and leak checks.
- Focus bridge (`Tab`, Shift+Tab, accelerators), scaling/DPI, resize, recreation and modal lifecycle.
- Dispatcher queue shutdown ownership and COM apartment teardown for repeated multi-dialog use.
- Full native `OodFluentControl` Rexx proxy API, including resource ID and UIA properties.

References: [Microsoft XAML Islands](https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/host-controls-existing-desktop-apps), [Microsoft Windows App SDK unpackaged bootstrap](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/use-windows-app-sdk-run-time).
