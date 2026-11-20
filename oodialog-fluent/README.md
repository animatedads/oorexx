# ooDialog Fluent Controls — native Windows extension

Architecture: Tom Dyer. Code: ChatGPT (GPT-6).

Status: **v0.4 bridge candidate; Windows native BUILD_PASS, ten HWND control types pass creation/property/update/teardown independently and together, and real ooDialog `UserDialog` integration exits cleanly 3/3 behind diagnostic thread opt-in**. The qualified native subset is `Button`, `ToggleSwitch`, `CheckBox`, `ToggleButton`, `Slider`, `RadioButton`, `RepeatButton`, `HyperlinkButton`, `AppBarButton` and `AppBarToggleButton`. Six programmatic native events reach distinct Rexx handlers in each live trial. The ten-control expansion has native HWND evidence in [run 44787628623](https://github.com/animatedads/oorexx/actions/runs/44787628623); its Rexx gate initially failed solely because the expected RadioButton revision was 2 instead of the **observed 3** after `text`, `groupName` and `isChecked` mutations. The corrected expectation is gated in [run 44788561646](https://github.com/animatedads/oorexx/actions/runs/44788561646). The broker still requires diagnostic opt-in. Physical input, visual/accessibility parity and the other 73 catalogue targets are not thereby qualified. `InfoBar`, `NumberBox`, `TextBox` and `ProgressBar` trigger a Windows App SDK access violation when closing the island and are disabled by default.

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
| Windows provider | Windows App SDK 2.6.5 DLL/ooRexx package BUILD_PASS; **ten** separate HWND control types and one combined island close cleanly ([run 44787628623](https://github.com/animatedads/oorexx/actions/runs/44787628623)) | Fix `InfoBar`/`NumberBox`/`TextBox`/`ProgressBar` island shutdown crash; qualify focus/keyboard |
| ooDialog integration | `::requires`-loading, native package calls, a real asynchronous **ten-control-type** `UserDialog`, **six** property-triggered WinUI → Rexx events and clean close PASS 3/3 on real ooRexx 5.2.0 ([green run 44788561646](https://github.com/animatedads/oorexx/actions/runs/44788561646)) with `OODF_TEST_CROSS_THREAD_HOOK=1` | Make cross-thread dispatch bounded/release-safe; verify `ResDialog`/`RcDialog`, physical user input and accessibility |
| Full coverage | Classification for stable, optional and unsupported controls; **10/83** catalogue types currently pass individual native HWND lifetime | Each control must pass functional and visual Windows tests |

`catalogue/controls.tsv` is a **target coverage catalogue, not an implementation claim**. Availability `stable` means Microsoft's API is available in the Windows App SDK stable channel, *not* that this project has implemented it. Experimental entries remain gated off by default. Existing Win32-compatible controls can retain their old ooDialog object behavior with a Fluent alternative selected explicitly.

Native `CheckBox.isChecked` currently supports programmatic `true` and `false`; the proposed tri-state write `null` remains **unqualified** and returns `E_NOTIMPL`. `isThreeState=true` is available, but programmatic indeterminate-state assignment was rejected by the Windows App SDK 2.6.5 host probe ([run 43762114741](https://github.com/animatedads/oorexx/actions/runs/43762114741)). The Rexx `setChecked(.nil)` convenience method will therefore raise an explicit native error until resolved.

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
radio = host~newRadioButton(2406, 'Alternate mode')
radio~setGroupName('Mode')
repeat = host~newRepeatButton(2407, 'Hold to repeat')
repeat~setDelay(500)
repeat~setInterval(100)
link = host~newHyperlinkButton(2408, 'Project website')
link~setNavigateUri('https://www.oorexx.org/')
barButton = host~newAppBarButton(2409, 'Save')
barToggle = host~newAppBarToggleButton(2410, 'Pin')
barToggle~setChecked(.true)
host~dispatchPendingVersioned  /* opt-in handler args: id, uid, value, revision */
```

`attach` must preserve `self` as the existing ooDialog object. Each new proxy holds an ooDialog resource ID and a unique occurrence UID; repeated legacy `IDC_STATIC` IDs remain distinguishable. Resource-authored UIDs can be passed as an optional final argument of each `new*` method (the fourth for `newControl`), preserving identity across renderer implementations and reopens. Native authored identities occupy decimal **1 through 2^63−1**; automatic identities start at **2^63** and remain session-local. A UID is single-use within one native session, even after removal. The Rexx bridge returns every UID as an **opaque `U`-prefixed string**, for example `U9223372036854775808`, not a Rexx number (default `NUMERIC DIGITS 9` cannot represent all uint64 values exactly). The native ABI still uses uint64. The proxies are prefixed `.OodFluent*`, do not inherit legacy `DialogControl`, and their event method is isolated from the legacy ooDialog event vocabulary. `getText`, `show`, `hide`, `enable`, `disable`, `setFocus` and richer value/selection methods are **planned**, not implemented; the preview exposes `setText`, `setValue`, `setChecked`, `setOn`, `setOpen` and `connectEvent`. New methods are additive; legacy `newButton` etc. remain unchanged. All property/event types require validation against the catalogue and each native WinUI API.

The native provider queues XAML events without calling Rexx from a XAML callback; Rexx drains them explicitly through the dialog activity. Native callbacks fired synchronously during a property write are deferred until the model revision advances, so the queued event records the revision of the updated property. `dispatchPending(limit)` keeps the legacy three handler arguments `(resourceId, uid, value)`; `dispatchPendingVersioned(limit)` or `dispatchPending(limit, .true)` passes `(resourceId, uid, value, revision)`. The event model and pending event-buffer retry use a single lock across those OS threads (tested with 300 concurrently produced events). ooDialog's HWND belongs to a different Windows thread than its Rexx `initDialog` activity. The prototype broker synchronously dispatches native host operations onto the HWND-owning thread. **It is not enabled by default**; `OODF_TEST_CROSS_THREAD_HOOK=1` is a CI/diagnostic switch until bounded cancellation and reentrancy are qualified. Add/update/remove operations use occurrence UID; callback envelopes include resource ID, UID, event, value and revision.

The Windows CI runtime gate requires the Microsoft-signed runtime and clean exit for the empty island, all ten candidate controls individually and in one combined island, and refusal of four unqualified controls. It also gates **three real ooRexx 5.2.0 `UserDialog` processes** (native-package load, ten control types, properties, six native property-triggered events → Rexx, async join and close) using the diagnostic GUI-thread broker. Separate **diagnostic** modes opt into unqualified `InfoBar`, `NumberBox`, `TextBox` and `ProgressBar` and record crashes without failing the limited supported-set gate. A green workflow badge qualifies **only these named cases**. The run-specific log and short-lived crash dump identify `Microsoft_UI_Xaml!DirectUI::XamlIsland::Close` dereferencing a null internal `IContentIsland` interface for `InfoBar` and `NumberBox`; `TextBox` and `ProgressBar` also crash at `CLOSE_ISLAND_BEGIN` in the same host, without separately symbolizing those dumps. **All four unsafe controls return `E_NOTIMPL` by default**; `OODF_ALLOW_UNQUALIFIED_NATIVE=1` is only for diagnostics. See `windows/README.md` for the qualification boundary.

## Tests

From this directory:

```sh
sh tests/run_tests.sh
```

Tests compile the native-independent core and its C-compatible ABI with a C++17 compiler, load and validate every catalogue entry, and exercise resource-ID collisions, authored occurrence UIDs, authored/automatic partitioning, rejected UID reuse, bound/unbound events, property validation, the five added button-family type contracts, experimental gating, destruction, stale-event suppression, a lossless event-buffer retry and a 300-event cross-thread producer/consumer exchange. Current local count: **1331/1331 PASS**. No Python runtime is used in the product. These are *not* Windows visual or ooRexx compatibility tests. Open identity questions: dynamic UID reuse/generation semantics across application lifetimes and the Designer's authored text-token canonicalization.

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
