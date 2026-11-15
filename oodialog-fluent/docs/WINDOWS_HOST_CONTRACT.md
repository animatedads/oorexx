# Windows host contract — qualification gate

Architecture: Tom Dyer. Code: ChatGPT (GPT-6).

The provider is implemented in native C++/WinRT. It is loaded as a Windows-only ooRexx extension and **hosts** actual `Microsoft.UI.Xaml` controls. It does not replace `oodialog.dll` and does not establish application truth in a renderer.

## Lifecycle

1. Existing ooDialog creates its top-level HWND and starts its message pump.
2. Fluent host negotiates Windows App SDK runtime, UI-thread STA and dispatcher queue. If the dialog's thread cannot host XAML, return `UNSUPPORTED_THREAD` without changing the existing dialog. Never move an HWND between threads.
3. `WindowsXamlManager.InitializeForCurrentThread` then `DesktopWindowXamlSource.Initialize(Win32Interop.GetWindowIdFromWindow(parent HWND))` establish the island. The island root is a `Grid` or another supported container. A window may have multiple islands; registration and teardown must be deterministic.
4. `create(resourceId, occurrenceUid, type, properties)` creates an actual named WinUI control. Keep the mapping `UID -> XAML object` inside the provider. Never expose this XAML object to Wire or other renderers.
5. Property updates and control destruction run on the owning UI thread. Native XAML events become typed FIFO messages `{id, uid, event, value, revision}` consumed by ooDialog's event dispatch; the Rexx handler remains responsible for changes to the application model.
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

## Provenance and status

This is a Windows provider contract, not a claim that the C++/WinRT island has been compiled or tested. `LOCAL_PASS` applies only to the independent model in v0.1.
