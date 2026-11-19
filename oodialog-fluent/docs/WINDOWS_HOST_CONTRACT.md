# Windows host contract — qualification gate

Architecture: Tom Dyer. Code: ChatGPT (GPT-6).

The provider is implemented in native C++/WinRT. It is loaded as a Windows-only ooRexx extension and **hosts** actual `Microsoft.UI.Xaml` controls. It does not replace `oodialog.dll` and does not establish application truth in a renderer.

## Lifecycle

1. Existing ooDialog creates its top-level HWND and starts its message pump.
2. Fluent host negotiates Windows App SDK runtime, UI-thread STA and dispatcher queue. If the dialog's thread cannot host XAML, return `UNSUPPORTED_THREAD` without changing the existing dialog. Never move an HWND between threads.
3. `WindowsXamlManager.InitializeForCurrentThread` then `DesktopWindowXamlSource.Initialize(Win32Interop.GetWindowIdFromWindow(parent HWND))` establish the island. The island root is a `Grid` or another supported container. A window may have multiple islands; registration and teardown must be deterministic.
4. `create(resourceId, occurrenceUid, type, properties)` creates an actual named WinUI control. Keep the mapping `UID -> XAML object` inside the provider. Never expose this XAML object to Wire or other renderers.
5. Property updates and control destruction run on the owning UI thread. Native XAML events become typed FIFO messages `{id, uid, event, value, revision}` consumed by ooDialog's event dispatch; the Rexx handler remains responsible for changes to the application model. XAML callbacks fired synchronously by a setter are buffered until the corresponding native model revision is committed. The old Rexx dispatcher delivers three callback arguments; the opt-in `dispatchPendingVersioned` delivers revision as the fourth.
6. `resize` calls `DesktopWindowXamlSource.SiteBridge.MoveAndResize` with an appropriately DPI-adjusted rectangle; re-parenting and focus moves are explicit. Destroy control event subscriptions before the island, and the island before its XAML environment.

## Test gates for native build

- `UserDialog`, `ResDialog`, `RcDialog`: old programs continue unchanged. Modal/modeless, tab order and accelerator navigation validated with physical keyboard and UI Automation.
- Control creation by numeric and symbolic resource IDs, including repeated `IDC_STATIC` occurrences, across dialog recreate/reopen.
- Stable WinUI controls: properties, constraints, default values, events, appearance, keyboard/mouse/touch, disabled/hidden, and a11y; no control gets a PASS merely for appearing on screen.
- Theme switching and OS follow; accent, scaling 100/125/150/200%, RTL, high contrast, screen-reader names; suspend/resume and runtime missing.
- Runtime unavailable, invalid parent, wrong thread, missing optional control, unknown property/event and a stale UID must fail visibly with typed errors.
- Reentrancy, teardown while a control event is pending, focus exchange between legacy HWND children and island children, and zero memory/handler leaks after 100 create/destroy cycles.
- Windows x64 and ARM64 native build/test; Windows 10 and 11 supported baselines. Linux and WASM never load a WinUI module.

## Separation from Designer and Wire

The Designer may author an optional `fluentType` and its properties in a resource object and preview it, without assuming the WinUI provider exists. Preserve the native `resourceId`, occurrence `uid`, and bound handler provenance. The Wire bridge maps such content into a semantic component or a clearly marked `RESOURCE_CONTROL` fallback; never make a HWND, visual tree or XAML serialization the semantic authority.

### Occurrence identity compatibility (Qt6 review A1/A4/A5)

- `resourceId` is **not** occurrence identity: multiple distinct controls may legitimately carry the same resource ID.
- The native core reserves authored integral UIDs **1…9223372036854775807** and automatically allocates **9223372036854775808…18446744073709551614**. An automatic control created first can no longer consume a future authored UID=1. Zero and authored values in the automatic range are rejected. No UID reuse in the same session, even after removal.
- The ooRexx boundary emits opaque strings `U<exact unsigned decimal>` for both authored and automatic UIDs; a 64-bit integer returned as a bare numeric string could otherwise compare incorrectly with default ooRexx `NUMERIC DIGITS 9`. The native C ABI remains uint64. Bare decimal input tokens are provisionally accepted for migration but not emitted.
- `dispatchPending` keeps the three-argument handler signature; `dispatchPendingVersioned` adds revision as the fourth argument. Setter-origin callbacks receive the model revision **after** that property mutation, not the preceding revision.
- **Not decided:** whether authored Designer text tokens are reversible/canonicalized, and whether long-lived UID reuse needs an explicit generation/epoch. Do not invent those semantics when merging cross-renderer assets. See Rasen Falcon Qt6 review `REQ-00003737`.

## Provenance and status

The Windows x64 DLL compiles and the standalone HWND subset (empty island,
`Button`, `ToggleSwitch`, `CheckBox`, `ToggleButton`, `Slider`) runs through
clean teardown both individually and all together. GitHub CI run
[43761615206](https://github.com/animatedads/oorexx/actions/runs/43761615206)
also runs a real ooRexx 5.2.0 `UserDialog` three times through the
**diagnostic opt-in same-process UI-thread broker**. Each process creates five
native controls, dispatches four property-triggered native events to distinct
Rexx methods, closes through `endAsyncExecution`, and exits with code 0.
The ABI event queue and retained buffer-retry envelope use one session lock
to protect operations across GUI and Rexx threads (300-event concurrency test).
`InfoBar`, `NumberBox`, `TextBox` and `ProgressBar` are disabled by default:
they trigger `0xC0000005` on island close even after native removal in this
host. This does not qualify unrestricted broker use, modal/resource dialogs,
physical input, accessibility, complex-template shutdown, or the other 78
catalogue targets.

The identity/event provenance update passed **1315/1315** local and
Windows/Ubuntu native-independent contract checks. [Windows CI run 44518725960](https://github.com/animatedads/oorexx/actions/runs/44518725960)
passed the native provider and three independent real ooRexx `UserDialog`
processes, each with an automatic `U9223372036854775808` followed by authored
`U1` and four versioned callback events: ToggleSwitch revision 2, CheckBox
revision 2, ToggleButton revision 2 and Slider revision 1. These are
**property-triggered callbacks**, not a qualification of physical input.
