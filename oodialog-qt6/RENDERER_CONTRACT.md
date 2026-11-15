# ooDialog renderer contract (draft, as read from oodWeb.cls 0.6.0 and oodialog-web.js at `05e1fb8`)

**Written by:** Claude (Opus 5.5), 14 Nov 2026. **Architecture:** Tom Dyer. **oodWeb.cls and oodialog-web.js:** Claude (Fable 5.2).

`oodWeb.cls` answers upstream ooDialog's native entry points. It reaches a renderer through one object and receives the renderer's events through one handler. Two renderers implement this today: `oodialog-web.js` in the browser, and `oodqt` (Qt6) on Linux. This file records the interface so that both can keep to it. **Proposal to the ooDialog/WASM chat:** treat this as the contract, as was done for `resourceProvider`, and change it only by agreement.

## What oodWeb.cls takes from js.cls

| Use | Meaning |
|---|---|
| `.js~page["__ood"]` | the renderer object |
| `.js~undefined` | "renderer not loaded yet"; the browser then loads `oodialog-web.js` |
| `.js~handler(target, "PAGEEVENT")` | the renderer's events go to `target~pageEvent` |
| `.js~nextEvent(seconds)` | wait up to `seconds` for one event; `.nil`, or an object whose `~dispatch` delivers it |

## The renderer's 15 messages

Every value is a string. `key` is the dialog's number, and `id` is a control id, with 0 meaning the dialog itself.

| Message | Arguments | Returns |
|---|---|---|
| `setHandler` | handler | `1` |
| `create` | spec (key x y cx cy title opts fontName fontSize [modeless parent px py]), controls | `fx fy width height`: dialog base units and pixel size |
| `addControl` | key, control (kind id x y cx cy text opts) | |
| `show` | key, how (`HIDE` or anything else) | `1`/`0` |
| `destroy` | key | `1`/`0` |
| `sub` | key, id, code | `1`: report this id's notification code; `*` is a wildcard |
| `op` | key, id, name, a, b, c | depends on `name` (see oodialog-web.js `ood.op`) |
| `msg` | key, id, msg, wParam, lParam | the Win32 message's result (BM_, EM_, LB_, CB_, PBM_ …) |
| `measure` | text, fontName, fontSize | `dluW dluH pxW pxH fx fy` |
| `screen` | | `width height` |
| `setMenu` | key, records | `1`; records `depth 1F id 1F text 1F flags`, joined by `1E`, depth first |
| `popupMenu` | token, x, y, records | answers later as event `MSGBOX(token, chosenId)` |
| `msgBox` | token, text, title, buttons, icon | answers later as event `MSGBOX(token, IDOK…)` |
| `image` / `hasImage` | name, data URL / name | `1` / `1`,`0` |

## Events: `pageEvent(key, kind, id, code, extra)`

| kind | When |
|---|---|
| `CMD` | WM_COMMAND: button, check and radio clicks always fire (code 0). Other notification codes fire only when `sub` asked for them. The close box and Escape give `CMD 2 0`, Enter without a default button `CMD 1 0`, F1 `CMD 9 0`. |
| `NOTIFY` | WM_NOTIFY from list-views, tree-views, tabs and the like (`extra` carries the detail) |
| `CTX` | context menu, when `sub(key, 0, "CTX")` was asked for: id, x, y |
| `KEY` | key press, when `sub(key, 0, "KEY")` was asked for: virtual key, modifiers `S C A` |
| `MSGBOX` | the answer to a `msgBox` or `popupMenu` |

Dialog units follow Windows: `fx = floor((avgWidth("A…Za…z")/26 + 1)/2)/4`, `fy = round(fontHeight)/8`, with the font at `size × 96/72` pixels.

## Tests

Both renderers run the same `tests/*.rex`, `.steps` and `.expect`. A `TEST.files/` folder holds support files placed beside the program. The steps use CSS-style selectors from the browser, such as `.ood-dlg >> text=OK`, `.ood-check input` and `.ood-menubar >> text=Demo`. The Qt player maps them onto widgets; see `native/oodqt.cpp`, `find()`.

## Separators inside arguments (added 15 Nov 2026, v0.3.0)

`oodWeb.cls` puts its separator (`self~sep`, `1F`) inside single arguments: `tv.ins`'s third argument is `text SEP opts`, `lv.insRow`'s second is the row's cells, and a NOTIFY's `extra` is several parts. In the browser every argument is a separate JavaScript value, so nothing is lost. A renderer that carries the messages as one string must keep each argument whole: `js.cls` sends an argument's own `1F` as `1D`, and `oodqt` restores it; an event record is split into its first four fields, and the rest is `extra`.

The NOTIFY `extra` formats both renderers send, as `oodWeb.cls~notify` reads them:

| Control | code | extra |
|---|---|---|
| list-view | `SEL` | item SEP `SELECTED`/`UNSELECTED` |
| list-view | `FOC` | item SEP `FOCUSED`/`UNFOCUSED` |
| list-view | `CHECK` | item SEP `CHECKED`/`UNCHECKED` |
| list-view | `CLICK`, `DBLCLK` | item SEP column SEP keys |
| list-view | `COLUMNCLICK`, `ACTIVATE` | column / item |
| tree-view | `SELCHANGED` | old SEP new SEP action |
| tree-view | `EXPANDING`, `EXPANDED` | node SEP `EXPANDED`/`COLLAPSED` |
| tab | `SELCHANGING`, `SELCHANGE` | (none) |
| track bar | `TRACK` | position SEP `DRAG`/`ENDTRACK` |
| up-down | `DELTAPOS` | position SEP delta |
| date-time picker | `DATETIMECHANGE` | `yyyy-mm-ddThh:mm:ss` |

Item and node numbers are the renderer's; `oodWeb.cls` turns a node number into the handle Rexx sees (`tvHandle`).

## Known difference: `.application~srcDir`

`oodWeb.cls` answers `srcDir` with the directory of `oodWeb.cls` itself (`parse source`), where upstream answers the directory of the program. In the page every file is in `/home/rexx`, so the two agree; on Linux they do not. Proposed fix (for the ooDialog/WASM chat to decide): the program's own package, `.context~stackFrames~lastItem~executable~package~name`. Checked on ooRexx 5.3 from a class in another directory (it gives the program, `parse source` gives the class). On a thread started by `reply` or `start` the last frame is that thread's first, so the value is best taken once, at load, and kept.
