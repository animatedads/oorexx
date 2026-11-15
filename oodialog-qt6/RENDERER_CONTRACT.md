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

## Known difference: `.application~srcDir` (fixed in oodialog-wasm v0.13.0)

`oodWeb.cls` answers `srcDir` with the directory of `oodWeb.cls` itself (`parse source`), where upstream answers the directory of the program. In the page every file is in `/home/rexx`, so the two agree; on Linux they do not. Proposed fix (for the ooDialog/WASM chat to decide): the program's own package, `.context~stackFrames~lastItem~executable~package~name`. Checked on ooRexx 5.3 from a class in another directory (it gives the program, `parse source` gives the class). On a thread started by `reply` or `start` the last frame is that thread's first, so the value is best taken once, at load, and kept.

## Drawing, images and sizing (added 15 Nov 2026, v0.4.0, as read from oodialog-wasm `155e1b0`)

**`op(key, id, "gdi", verb, values, style)`.** id 0 is the client area; any other id is that control. `values` and `style` are lists joined by SEP. `style` is: stroke, width, dash (`SOLID DASH DOT DASHDOT DASHDOTDOT NULL`), fill (`#rrggbb`, `hatch:KIND:#rrggbb`, or empty for no brush), font (CSS: `[italic] [bold] Npt "Name", sans-serif`, or empty for the dialog's), text colour, background mode (`O`/`T`), background colour, and align words (`LEFT CENTER RIGHT TOP BOTTOM BASELINE`).

| verb | values | returns |
|---|---|---|
| `line` | x1 y1 x2 y2 | `1` |
| `rect` | left top right bottom fill(1/0) | `1` |
| `arc` | left top right bottom xStart yStart xEnd yEnd pie(1/0) direction | `1`; counter-clockwise unless `CLOCKWISE` |
| `angleArc` | x y radius start sweep [fromX fromY] | the end point `x y` |
| `pixel` / `getPixel` | x y colour / x y | `1` / `r + g*256 + b*65536`, `-1` where nothing is drawn |
| `fillRect` | left top right bottom | `1` |
| `clear` | (empty: all) or left top right bottom | `1` |
| `extent` / `text` | text / x y text (lines split on LF) | `width height` / `1` |
| `flood` | x y borderColour | `1` |
| `image` | key x y xSource ySource width height (0: all) | `1`, `0` if the image is unknown (BitBlt) |
| `scroll` | dx dy [left top right bottom] | `1` (ScrollWindow; what leaves the part is cut off) |
| `ownerDraw` / `size` | | `1` / `width height` of the drawing surface |

**Images.** The `image(name, dataURL)` message carries each file once, and `hasImage(name)` answers `1` or `0`. These ops then use the image by its key:
- `op(…, "image", key, ["STRETCH"])` sets a static image's picture.
- `op(…, "bitmap", normal, focused SEP selected SEP disabled, style)` installs a bitmap button. With `STRETCH` the picture fills the button; without `FRAME` the button has no frame.
- `op(…, "bitmapPos", x, y)` (setBitmapPosition) places the picture's top left within the button.
- `op(…, "backdrop", key, "TILE"|"STRETCH")` puts a picture behind the dialog or a control.

**Sizing.** A top-level dialog created with `THICKFRAME` can be resized. After `sub(key, 0, "RESIZE")` it reports `WM 0 RESIZE width SEP height`, in client-area pixels. After `sub(key, 0, "SIZEMOVEENDED")` it reports `WM 0 SIZEMOVEENDED` 250 ms after the last change. Opening at its own size is not a change.

**Threads (a proposal for oodWeb.cls).** The renderer has one event queue. Any Rexx thread that calls `nextEvent` takes the next event, as in the page. `msSleep` and `winTimer WAIT` call it on every thread, so a method that replied and loops (AnimatedButton) can take, and run, the dialog's events on its own thread. In up/oowalker it then waits on itself. The proposal: take events only on the thread that runs `pumpUntilFinished`, which can be recognised by its bottom stack frame's executable; any other thread just sleeps, as on Windows. With that change, made on a staged copy only, oowalker ended in the run tested; it should be checked over many runs.

## A renderer's resource reader (proposed 15 Nov 2026, v0.5.0)

`.JS~resourceProvider` (class method, Qt renderer only) answers a reader of binary Windows resources (.dll, .exe, .res), or `.nil`. The Qt renderer answers alchemy's `oorexx_win_resources` (`WinResourceProvider`) when `WinResources.cls` is on `REXX_PATH`; one reader serves every dialog. The proposal: when a ResDialog or BinaryMenuBar needs a reader and `.oodn~resourceProvider` was not set, `oodWeb.cls` asks `.js`, if `.js` has the method. Nothing changes in the page. This and three other changes, with the samples they fix, are in `proposals/` as a patch to v0.13.1.

The thread proposal above (msSleep) was taken in oodialog-wasm v0.13.1; oowalker passed 10 of 10 runs against it.

## The mouse (added 15 Nov 2026, v0.6.0, as read from oodialog-wasm `0e0e744`, v0.14.0)

- **`op(key, id, "mouseSub", NAME)`** connects one Windows mouse event of the dialog (id 0, its client area) or a control. NAME is one of `LBUTTONDOWN`, `LBUTTONUP`, `LBUTTONDBLCLK` (also `M…` and `R…`), `MOUSEMOVE`, `MOUSEWHEEL`, `MOUSEHOVER` or `MOUSELEAVE`. The event comes back as `MOUSE id NAME "state x y delta"`:
  - **state:** the words `Control lButton mButton rButton Shift` that apply, joined with commas, or `None`.
  - **x y:** in the host's client area; for `MOUSEWHEEL` they are on the screen.
  - **delta:** the wheel's ±120 (up is +).
  - **Timing and routing:** at most one `MOUSEMOVE` is sent per 30 ms, and the last move is never dropped. `MOUSEHOVER` comes 400 ms after the pointer enters. An event over a control reaches every connected host that contains it.
  - **The wheel:** a connected `MOUSEWHEEL` takes the wheel; the control under it does not scroll.
- **`op(key, id, "mouse", verb[, arg])`**:
  - `capture`, `release` and `getCapture` answer the previous holder as `key id`, or empty. While one window holds the capture, mouse moves and button releases anywhere go to it alone.
  - `state` answers `x y buttons`, where buttons are 1 left, 2 right, 4 middle.
  - `cursor NAME` sets the cursor for every dialog and answers the previous one. NAME is a CSS cursor name or the key of a `.cur`/`.ico` image Rexx sent.
- **`lv.hit x y`** answers the list-view row and column at a point of the control, as `"row col"`, or `-1 0` for none.
- **`EM_SCROLL` (0xB5)** on a multi-line edit scrolls by a line or a page and answers 65536 plus the lines moved.

**Geometry the page has and Windows programs rely on.** A list-view row is a line and 2 px high, and its header a line and 5 px. Programs hit-test by pixel (dragNdrop drags the row at y=34), so the Qt renderer gives its rows the same heights. A press with a move does not select rows on Windows: it is LVN_BEGINDRAG, for the program to handle.

## In-place editing and tab stops (added 15 Nov 2026, v0.7.0, as read from oodialog-wasm `fc16dfb`, v0.15.0)

- `op(key, id, "setParent", parentId)`: the control is shown on, and placed in, another control. From then on, `move` positions are in that control's client area. For a list-view, the client area is inside its frame and includes the header.
- `op(key, id, "grandChild", tab)` (isGrandChild): RETURN, ESCAPE and losing the focus come back as `GC id enter|escape|killfocus`, and so does TAB when `tab` is `1`. Those keys don't reach the dialog's default button or its Cancel.
- `size` on a drop-down combo keeps the box's own height; `cy` is the height of its list.
- `lv.rect row [col]` (getItemRect / getSubitemRect) answers `l t r b` for the row or one cell, in the control's client area.
- A list-view reports `NOTIFY id BEGINSCROLL dx SEP dy` when its view starts to move, and `ENDSCROLL` when it has rested for 150 ms. Rows the program puts in don't count as moving.
- `op(key, id, "tabStops", "s1 s2 …")` (LB_SETTABSTOPS) gives the stops in pixels. The items keep their text; each tab is shown filled out to the next stop.
- A list-view click and double click: the second click of a double click is reported as `CLICK` and then `DBLCLK`, as the page (Chromium) does. Qt alone reports only the double click.
