# ooDialog Fluent Controls — native Windows extension

Architecture: Tom Dyer. Code: ChatGPT (GPT-6).

Status: **v0.3 bridge candidate; Windows native BUILD_PASS, five HWND controls pass creation/property/update/teardown independently and together, and real ooDialog `UserDialog` integration passes 3/3 behind diagnostic thread opt-in**. The native HWND and live ooRexx 5.2.0 smoke qualifies `Button`, `ToggleSwitch`, `CheckBox`, `ToggleButton` and `Slider`; four programmatic native events reach distinct Rexx handlers in each trial ([CI 43761615206](https://github.com/animatedads/oorexx/actions/runs/43761615206)). The broker still requires diagnostic opt-in. Physical input, visual/accessibility parity and the other 78 catalogue targets are not thereby qualified. `InfoBar`, `NumberBox`, `TextBox` and `ProgressBar` trigger a Windows App SDK access violation when closing the island and are disabled by default.

## Objective

Add the Windows 10/11 Fluent Design control catalogue to existing ooDialog applications *without changing the meaning of existing ooDialog programs*. Use the native Microsoft Windows App SDK WinUI 3 control implementations rather than drawing imitations. Expose normal ooRexx proxy objects, resource IDs and event handlers; keep HWND/COM/XAML objects inside a Windows-only provider.

The extension is deliberately distinct from:

- `oodialog-designer`: authoring ordinary upstream ooDialog resources, including `::RESOURCE`.
- `oodialog-wasm`: the browser/WASM re-host of upstream ooDialog.
- `oodialog-linux`: Qt6 compatibility rendering for existing programs.
- Wire UI: the separate authoritative application/semantic renderer architecture. Import/export must preserve semantic identity independently of HWND.

## Delivery sequence

| Layer | v0.1 evidence | Next qualification |
| --- | --- | --- |
| 83-control and pattern inventory | Catalogue and automated validation | Compare every entry with current Microsoft WinUI 3 Gallery |
| Resource occurrence identity, proxy properties, event routing and lifecycle | Native-independent C++ core and C ABI, executable tests; native-event queue and pending-retry envelope protected across GUI/Rexx threads | Qualify concurrent physical user input and bounded broker |
| Windows provider | Windows App SDK 2.6.5 DLL/ooRexx package BUILD_PASS; five separate HWND control families and one combined island close cleanly ([run 43761615206](https://github.com/animatedads/oorexx/actions/runs/43761615206)) | Fix `InfoBar`/`NumberBox`/`TextBox`/`ProgressBar` island shutdown crash; qualify focus/keyboard |
| ooDialog integration | `::requires`-loading, native package calls, a real asynchronous five-control `UserDialog`, four property-triggered WinUI → Rexx events and clean close PASS 3/3 ([run 43761615206](https://github.com/animatedads/oorexx/actions/runs/43761615206)) with `OODF_TEST_CROSS_THREAD_HOOK=1` | Make cross-thread dispatch bounded/release-safe; verify `ResDialog`/`RcDialog`, physical user input and accessibility |
| Full coverage | Classification for stable, optional and unsupported controls; **5/83** control types currently pass individual native HWND lifetime | Each control must pass functional and visual Windows tests |

`catalogue/controls.tsv` is a **target coverage catalogue, not an implementation claim**. Availability `stable` means Microsoft's API is available in the Windows App SDK stable channel, *not* that this project has implemented it. Experimental entries remain gated off by default. Existing Win32-compatible controls can retain their old ooDialog object behavior with a Fluent alternative selected explicitly.

## API preview (limited `UserDialog` native runtime qualification)

```rexx
/* Inside an ooDialog instance; catalogue location must be supplied. */
host = .OodFluentHost~attach(self, 'C:\\catalogue\\controls.tsv')
mode = host~newToggleSwitch(2401, 'Night mode')
mode~setOn(.true)
mode~connectEvent('toggled', 'onNightModeChanged')
save = host~newButton(2402, 'Save')
accept = host~newCheckBox(2403, 'Accept')
accept~connectEvent('checked', 'onAccepted')
pin = host~newToggleButton(2404, 'Pin')
level = host~newSlider(2405, 'Volume')
level~setValue(42.5)
host~dispatchPending  /* call from the dialog UI event pump, not a busy loop */
```

`attach` must preserve `self` as the existing ooDialog object. Each new proxy holds an ooDialog resource ID and a unique occurrence UID; repeated legacy `IDC_STATIC` IDs remain distinguishable. Resource-authored UIDs can be passed as an optional final argument of each `new*` method (the fourth for `newControl`), preserving identity across renderer implementations and reopens. Automatic UIDs remain session-local; every UID is single-use within one native session. The proxies are prefixed `.OodFluent*`, do not inherit legacy `DialogControl`, and their event method is isolated from the legacy ooDialog event vocabulary. `getText`, `show`, `hide`, `enable`, `disable`, `setFocus` and richer value/selection methods are **planned**, not implemented; the preview exposes `setText`, `setValue`, `setChecked`, `setOn`, `setOpen` and `connectEvent`. New methods are additive; legacy `newButton` etc. remain unchanged. All property/event types require validation against the catalogue and each native WinUI API.

The native provider queues XAML events without calling Rexx from a XAML callback; Rexx drains them explicitly through the dialog activity. The event model and pending event-buffer retry now use a single lock across those OS threads (tested with 300 concurrently produced events). ooDialog's HWND belongs to a different Windows thread than its Rexx `initDialog` activity. The prototype broker synchronously dispatches native host operations onto the HWND-owning thread. **It is not enabled by default**; `OODF_TEST_CROSS_THREAD_HOOK=1` is a CI/diagnostic switch until bounded cancellation and reentrancy are qualified. Add/update/remove operations use occurrence UID; callback envelopes include resource ID, UID, event, and value.

The Windows CI runtime gate requires the Microsoft-signed runtime and clean exit for the empty island, all five supported controls individually and in one combined island, and refusal of four unqualified controls. It also gates **three real ooRexx 5.2.0 `UserDialog` processes** (native-package load, five controls, properties, native property-triggered events → Rexx, async join and close) using the diagnostic GUI-thread broker. Separate **diagnostic** modes opt into unqualified `InfoBar`, `NumberBox`, `TextBox` and `ProgressBar` and record crashes without failing the limited supported-set gate. A green workflow badge qualifies **only these named cases**. The run-specific log and short-lived crash dump identify `Microsoft_UI_Xaml!DirectUI::XamlIsland::Close` dereferencing a null internal `IContentIsland` interface for `InfoBar` and `NumberBox`; `TextBox` and `ProgressBar` also crash at `CLOSE_ISLAND_BEGIN` in the same host, without separately symbolizing those dumps. **All four unsafe controls return `E_NOTIMPL` by default**; `OODF_ALLOW_UNQUALIFIED_NATIVE=1` is only for diagnostics. See `windows/README.md` for the qualification boundary.

## Tests

From this directory:

```sh
sh tests/run_tests.sh
```

Tests compile the native-independent core and its C-compatible ABI with a C++17 compiler, load and validate every catalogue entry, and exercise resource-ID collisions, authored occurrence UIDs, bound/unbound events, property validation, experimental gating, destruction, stale-event suppression, a lossless event-buffer retry and a 300-event cross-thread producer/consumer exchange. Current local count: **1307/1307 PASS**. No Python runtime is used in the product. These are *not* Windows visual or ooRexx compatibility tests.

## Platform and fallback contract

- Windows 10 build 17763+ / Windows 11, with supported Windows App SDK runtime and a single STA UI thread; verify the exact runtime target during the Windows build.
- Initialize the Windows App SDK runtime, dispatcher queue and `Microsoft.UI.Xaml.Hosting.WindowsXamlManager` before creating `DesktopWindowXamlSource`.
- Child HWND must follow parent resizing, DPI, input focus, keyboard navigation, high contrast, screen readers and UI Automation.
- Use theme resources (light/dark/system/accent), localization, scaling and accessibility from WinUI; no hardcoded Win11-looking bitmaps.
- If the runtime is unavailable, the provider must report a typed `RUNTIME_UNAVAILABLE` error; it must never silently change the behavior of legacy ooDialog controls. Optional explicitly configured classic Win32 fallback is acceptable only where behavior is equivalent.
- No experimental WinUI controls in a stable build. `TableView`, Chart and Ink are tracked as optional experimental targets; stable alternatives must be explicit.

### Primary references

- [Microsoft — Controls for Windows apps](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/)
- [Microsoft — Host WinUI controls with XAML Islands](https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/host-controls-existing-desktop-apps)
- [Microsoft — WinUI 3 feature gaps](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/migrate-to-windows-app-sdk/what-is-supported)
- [ooRexx — ooDialog Reference](https://www.oorexx.org/docs/pdf/oodialog.pdf)
