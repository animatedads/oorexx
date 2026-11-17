# Proposals for oodWeb.cls, from the Qt6 renderer

- **Architecture:** Tom Dyer
- **Coding:** Claude (Opus 5.5). The changes are to `oodWeb.cls` by Claude (Fable 5.2); that chat decides whether to take them.
- **Written by:** Claude (Opus 5.5), 15 Nov 2026; updated 16 Nov 2026

**16 Nov 2026, oodialog-wasm v0.19.0 (`ee4b515`):** v0.19.0 took the `tab_calcRect` change in its own form (calcDisplayRect keeps the rectangle given; `tab.outer`). The other three changes still apply: `oodWeb-v0.19.0-linux.patch` holds them, and applies to `ee4b515` with `git apply`. `oodWeb-v0.13.1-linux.patch` applied up to v0.18.0 and no longer applies to v0.19.0.

`oodWeb-v0.13.1-linux.patch` applies to oodialog-wasm `1d89981` (v0.13.1) and, unchanged, to `0e0e744` (v0.14.0) and `fc16dfb` (v0.15.0), with `git apply`. It was found by `tools/oodqt_sweep.rex` over upstream's samples on Linux. With the patch, 6 more samples come up that stopped with a Rexx error before. It is tested only on a staged copy, against those samples, on the Qt renderer; it has not been run in the browser.

| Change | Why | Samples |
|---|---|---|
| `needProvider`: when no reader was set, ask `.js~resourceProvider` (if the renderer has one) | A renderer can offer a reader of binary resources; the Qt renderer offers alchemy's `oorexx_win_resources` when it is on `REXX_PATH`. The page's `.js` has no such method, so nothing changes there. | oowalk2, propertysheet.tabControls/TabDemo, resizableDialogs/ResizingAdmin/TabDemo, Exercise04/Extras/DlgData/ASimpleDialog2 |
| `tab_calcRect`: move the rectangle by the tab control's margins, keeping its own co-ordinates | `calcDisplayRect` is TCM_ADJUSTRECT: upstream passes `windowRect` (screen co-ordinates) and then calls `screen2client`. Answering in client co-ordinates put every page up and to the left of the tab. | both TabDemo samples (the pages were misplaced) |
| `binMenu_init`: `BinaryMenuBar~new(.nil, id, …)` makes an empty menu bar, with no reader | Upstream: src `.nil` creates an empty menu that the program fills. | menus/BinaryMenuBar, tutorial/employe9menuDyn |
| `il_handle`: `numeric digits 20` | `identityHash` is 64-bit on a 64-bit interpreter; `d2x` failed (in the page it is 32-bit) | examples/imageButton (it now reaches an ImageList method not yet implemented) |
