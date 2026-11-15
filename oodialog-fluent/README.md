# ooDialog Fluent Controls — native Windows extension

Architecture: Tom Dyer. Code: ChatGPT (GPT-6).

Status: **v0.2 bridge candidate, Windows native BUILD_PASS and limited HWND runtime PASS, no ooDialog runtime qualification**. The C++ model passes on Windows/Linux, and the WinUI 3 provider and native ooRexx package compile on Windows. The separate native HWND smoke closes cleanly with an empty island, Button, or ToggleSwitch. InfoBar and NumberBox each trigger a WinUI 3 access violation when closing the island; a full hosted ooDialog program has not been run.

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
| Resource occurrence identity, proxy properties, event routing and lifecycle | Native-independent C++ core and C ABI, executable tests | Bind to ooRexx objects and WinUI host |
| Windows provider | Windows App SDK 2.6.5 DLL/ooRexx native-package BUILD_PASS; HWND runtime PASS for empty/`Button`/`ToggleSwitch` cases ([run 43724613822](https://github.com/animatedads/oorexx/actions/runs/43724613822)) | Fix `InfoBar`/`NumberBox` island shutdown crash, then run inside real ooDialog; focus/keyboard and UI-thread tests |
| ooDialog integration | `rexx/OodFluent.cls` proxy and native package added, not yet run in ooDialog | Test `::requires`-loading, native package linking, `UserDialog`/`ResDialog`/`RcDialog` message pump and UI thread compatibility |
| Full coverage | Classification for stable, optional and unsupported controls | Each control must pass functional and visual Windows tests |

`catalogue/controls.tsv` is a **target coverage catalogue, not an implementation claim**. Availability `stable` means Microsoft's API is available in the Windows App SDK stable channel, *not* that this project has implemented it. Experimental entries remain gated off by default. Existing Win32-compatible controls can retain their old ooDialog object behavior with a Fluent alternative selected explicitly.

## API preview (bridge candidate, not yet ooDialog-qualified)

```rexx
/* Inside an ooDialog instance; catalogue location must be supplied. */
host = .OodFluentHost~attach(self, 'C:\\catalogue\\controls.tsv')
mode = host~newToggleSwitch(2401, 'Night mode')
mode~setOn(.true)
mode~connectEvent('toggled', 'onNightModeChanged')
save = host~newButton(2402, 'Save')
host~dispatchPending  /* call from the dialog UI event pump, not a busy loop */
```

`attach` must preserve `self` as the existing ooDialog object. Each new proxy holds an ooDialog resource ID and a unique occurrence UID; repeated legacy `IDC_STATIC` IDs remain distinguishable. Resource-authored UIDs can be passed as the optional third argument of the four `new*` methods (the fourth for `newControl`), preserving identity across renderer implementations and reopens. Automatic UIDs remain session-local; every UID is single-use within one native session. The proxies are prefixed `.OodFluent*`, do not inherit legacy `DialogControl`, and their event method is isolated from the legacy ooDialog event vocabulary. `getText`, `show`, `hide`, `enable`, `disable`, `setFocus` and richer value/selection methods are **planned**, not implemented; the preview exposes `setText`, `setValue`, `setOn`, `setOpen` and `connectEvent`. New methods are additive; legacy `newButton` etc. remain unchanged. All property/event types require validation against the catalogue and each native WinUI API.

The real native provider will queue events on the UI thread and deliver them through ooDialog's own message/dispatch mechanism; it must not invoke Rexx arbitrarily from a XAML callback. The dialog must keep its message pump and source of behavioral truth. Add/update/remove operations are addressed by occurrence UID; callback envelopes include resource ID, UID, event, and value.

The Windows CI runtime gate requires successful installation of the Microsoft-signed runtime and a clean exit for the empty island, `Button`, `ToggleSwitch` and the unsafe-control refusal check. Separate **diagnostic** modes opt into the two unqualified control types and record crashes without failing this limited supported-set gate. Thus a green workflow badge qualifies only the named safe modes, **not the entire catalogue**. The run-specific log and short-lived crash dump identify `Microsoft_UI_Xaml!DirectUI::XamlIsland::Close` dereferencing a null internal `IContentIsland` interface for `InfoBar` and `NumberBox`; retaining children, clearing focus, pre-unloading them, and settling the dispatcher do not fix it. **The Windows provider refuses both unsafe controls with `E_NOTIMPL` by default**; `OODF_ALLOW_UNQUALIFIED_NATIVE=1` is for diagnostics only, not a release setting. See `windows/README.md` for the qualification boundary.

## Tests

From this directory:

```sh
sh tests/run_tests.sh
```

Tests compile the native-independent core and its C-compatible ABI with a C++17 compiler, load and validate every catalogue entry, and exercise resource-ID collisions, authored occurrence UIDs, bound/unbound events, property validation, experimental gating, destruction, stale-event suppression and a lossless event-buffer retry. Current local count: **101/101 PASS**. No Python runtime is used in the product. These are *not* Windows visual or ooRexx compatibility tests.

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
