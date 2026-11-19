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

## The renderer's 15 messages (17 from v0.12.0: see `deliver` and `windowAt` below)

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
| `KEY` | key press, when `sub(key, 0, "KEY")` was asked for: virtual key, modifiers `S C A`, and (from v0.21.0) the focused control's id in `extra` |
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

## Month calendar and ResizingAdmin (added 15 Nov 2026, v0.8.0, as read from oodialog-wasm `2423db8`, v0.16.0 and v0.17.0)

Month calendar (kind `MONTHCALENDAR`; styles `NOTODAY`, `WEEKNUMBERS`, `DAYSTATE`). Dates go both ways as `yyyy-mm-ddT00:00:00`.
- `mc.get` answers the selected day. `mc.set d` selects it and brings its month into view.
- `mc.today [d]` sets and answers the day the Today line shows.
- `mc.range min max` limits the days (an empty bound is none); `mc.getRange` answers `min SEP max`.
- `mc.months [P]` answers `first SEP last SEP count`: the month shown, or with `P` every day shown, the days of the months before and after included.
- `mc.dayState "m1 m2 …"` sets the bold days, one bit mask a month (bit 0 is the 1st), from the month of the first day shown; `mc.dayStateFrom d "m1 …"` does the same from d's month.
- `mc.firstDay [n]` sets and answers the first day of the week, Windows-numbered (0 is Monday).
- `mc.minRect` answers `w h`, the size the calendar needs; `mc.hit x y` answers `DATE d`, `TITLE`, `PREV`, `NEXT`, `TODAY` or `NOWHERE` for a point of the control.
- Messages: `MCM_GETMAXTODAYWIDTH` (0x1015) answers the Today line's width; `MCM_GETMAXSELCOUNT` (0x1003) and `MCM_GETMONTHDELTA` (0x1013) answer 1.
- Events: a day picked by the user is `NOTIFY id SELCHANGE` and then `SELECT`, with `extra` = `d SEP d`. With `DAYSTATE`, moving to another month asks `NOTIFY id GETDAYSTATE first-month SEP 3`, which the program answers with `mc.dayState`.
- The Qt renderer shows 42 days from the first cell as `QCalendarWidget` places them: a month that starts on the first day of the week starts one row down. The first day shown and the month GETDAYSTATE asks for follow that, so they can differ from the page by a week; the bold days still land on the cells the user sees.

ResizingAdmin:
- `op(key, 0, "ra.init", JSON)` makes the dialog sizable and pins its controls. JSON is `{"def": [L, T, R, B], "ctrls": [[id, L, T, R, B], …], "min": …, "max": …, "ended": 0|1}`, and each edge is `[type, edge, toId]`: type `P` proportional, `S` stationary, `ML` my left (a right edge), `MT` my top (a bottom edge); edge `LEFT TOP RIGHT BOTTOM XCENTER YCENTER`; toId 0 for the dialog. The controls named come first, in the program's order, then the others as created, with the default edges.
- `min` and `max` are `"initial"` (the size at `ra.init`), `[w, h]` in pixels, or `null`; `op(key, 0, "ra.limits", min, max)` changes them. With no minimum the client area can shrink to 60 x 30.
- On every size change each control's edges are worked out in that order, from the original and current rectangles of what it is pinned to. With `ended` 1, `WM 0 RASIZEENDED` comes 250 ms after the last change.

Editable combo box:
- `op(key, id, "isDropList")` answers 1 for a drop-down list, 0 for a combo with an edit; `getEditControl` uses it.
- An Edit object over a combo's id (its edit part) is the combo: `grandChild` on it reports RETURN, ESCAPE and losing the focus as the combo's.
- Adding items leaves an editable combo's edit text as it was, and nothing is current until the program selects. Taking the focus selects the edit's text, and Enter adds no item.

## Tool tips (added 15 Nov 2026, v0.9.0, as read from oodialog-wasm `71f3590`, v0.18.0)

A ToolTip is not a control. It is a set of tools that its dialog keeps under the tool tip's ID, plus one floating box for the whole process. Every operation is `op(key, ttId, "tip.NAME", a, b)`, and the ID is never looked up as a control.
- `tip.add JSON`: JSON is `{"key", "host", "rect": [l, t, r, b] | null, "text": "…" | null}`. host is a control's ID, or 0 for the client area. A rect is in that window's client pixels, with r and b outside it. A text of null is asked for each time. A tool with the same key replaces the old one.
- `tip.del key`.
- `tip.text key text`: a text of a single SEP makes it asked again.
- `tip.relay hostId 1|0`: the pointer's moves over that window go to the program.
- `tip.count`.
- `tip.delay ms`: the initial delay. It is the only delay used.
- `tip.maxWidth px`: answers the old width, or -1. With a width the text wraps.
- `tip.title text`; `tip.active 1|0`; `tip.events "SHOW POP NEEDTEXT RELAY …"`.
- `tip.show text`: the answer to NEEDTEXT or GETINFOTIP. An empty text shows nothing.
- `tip.pos x y`: the box's place in screen pixels, for setWindowPos from a SHOW method.
- `tip.pop`: ends the tip. If the pointer is still on the tool, the tip is due again after the delay.
- `tip.shown`: answers `toolKey SEP text`, or nothing.
- `tip.tree id`: the tree-view asks GETINFOTIP for its items.

When the pointer rests on a tool for the delay, a fixed text is shown and `TT ttId SHOW toolKey` is sent. An asked text sends `TT ttId NEEDTEXT toolKey` instead, and the program answers with `tip.show`. `TT ttId POP toolKey` is sent when the box goes. Leaving the tool's window, or a press in it, ends the tip and its wait. A window is the innermost control under the pointer, or the client area where there is no control. For a relayed window, each move sends `TT ttId RELAY toolKey SEP x SEP y`, in its client pixels. A tree-view with GETINFOTIP connected sends `NOTIFY id GETINFOTIP h` for the item under the pointer, and the program answers with `tip.show` on tool tip 60000 + id. The box appears 12 pixels right of and 20 below the pointer, inside the screen. In Qt it is a window of its own that takes no input.

Tree-view additions for tips:
- `tv.hit x y` answers `h LOCATION`: `ONITEM ONLABEL`, `ONBUTTON`, `ONINDENT`, `ONRIGHT`, or `0 NOWHERE`.
- `tv.rect h [1]` answers `l t r b` in the client area: the whole row, or with 1 only its text. It answers nothing for an item that is not shown.

The page no longer has the `tip` op (the browser's title text). The Qt renderer still answers it, for older oodWeb releases.

## pagedTab, tab and button additions (added 16 Nov 2026, v0.10.0, as read from oodialog-wasm `ee4b515`, v0.19.0)

- `op(key, tabId, "ra.page", childKey)` names an embedded dialog as a page of that tab control. After every ResizingAdmin layout of the owner, each page is moved and sized to the tab's display area, 2 pixels inside it. A page that has its own sizing definition is then laid out by its size change.
- `op(key, 0, "size", w, h)` on an embedded dialog lays it out at once when it is a ResizingAdmin dialog. The page has no observer for this; the Qt renderer gets it from the client area's resize.
- `op(key, tabId, "tab.outer")` answers `l t r b`: the whole tab control in the dialog's client area. calcDisplayRect uses it with `tab.rect` to move the rectangle it was given by the tab's margins, keeping that rectangle's own coordinates (TCM_ADJUSTRECT).
- `TCM_SETMINTABWIDTH` (0x1331) with lParam the width (or -1 for the default) answers the width before.
- `BM_SETSTATE` (0xF3) draws a button pushed (wParam 1) or not (0), and `BM_GETSTATE` (0xF2) reports it as bit 4.

## Virtual-key codes (added 17 Nov 2026, v0.11.0, for oodialog-wasm `aad1631`, v0.19.1, demo/calckeys)

A `KEY` event names the key pressed, as Windows does and the page's keyCode gives it, not the character it made. The codes are for a US layout:
- A-Z: 65-90; 0-9: 48-57. A shifted digit (`! @ # $ % ^ & * ( )`) is its digit's key: `*` is 56 with `S`.
- `; :` 186, `= +` 187, `, <` 188, `- _` 189, `. >` 190, `/ ?` 191, `` ` ~ `` 192, `[ {` 219, `\ |` 220, `] }` 221, `' "` 222.
- The number pad: 0-9 are 96-105, `*` 106, `+` 107, `-` 109, `.` 110, `/` 111.
- Backspace 8, Tab 9, Enter 13, Escape 27, Space 32, PageUp 33, PageDown 34, End 35, Home 36, the arrows 37-40, Insert 45, Delete 46, F1-F24 112-135.
The modifiers held are given as `S` (Shift), `C` (Control) and `A` (Alt).

## Standby printer, windowAt, status bar and more natives (added 19 Nov 2026, v0.12.0, as read from oodialog-wasm `be78d99`, v0.20.0 and v0.21.0)

Two new renderer messages, so the list above is now 17:

| Message | Arguments | Returns |
|---|---|---|
| `deliver` | name, mime, hex, title | `1`: the bytes (as hex) are handed to the user. The page offers them for download. The Qt renderer writes them to a folder of their own (`OODQT_DELIVER`, or the temporary folder's `oodqt-deliver-PID`) and shows a window `ood-deliver` with Print (a printer dialog, then CUPS `lp`), Open (the desktop's viewer, `xdg-open`), Save (a file dialog) and Close. A PDF shows as pages when `pdftoppm` is installed; a text or an image as itself. |
| `windowAt` | x, y (screen) | `key id`: the innermost dialog at the point (an embedded dialog before its owner) and the control under it, 0 for none; nothing when no dialog is there. |

Ops added by v0.21.0:
- `STATUSBAR` controls, docked along the bottom of the client area at its full width, whatever rectangle the program gave. Parts are numbered from 0; an edge is a part's right edge in the bar's pixels, -1 "to the end". `sb.setParts "e1 e2 …"`, `sb.parts`, `sb.setText part text`, `sb.text part`, `sb.has part`, `sb.setTip part text`, `sb.tip part`, `sb.simple 1|0`, `sb.isSimple`, `sb.rect part` (`l t r b`, from the edges, as SB_GETRECT; nothing for no such part), `sb.minHeight px`, `sb.bk css` (answers the colour before). Part 255 is the simple mode's text (Windows' 256). `getText`/`setText` on the bar use part 0.
- `color` with id 0 colours the dialog's client area. Colours arrive in CSS form: `#rrggbb`, a name, or `rgb(r,g,b)` (oodWeb's `colorOf` for a COLORREF). A renderer must read `rgb()`; Qt's `QColor(QString)` does not, and gave black.
- Edits: `getCue` (EM_GETCUEBANNER), `lineOf [char]`, `lineStart [line]`, `lineLen [line]` (EM_LINEFROMCHAR, EM_LINEINDEX, EM_LINELENGTH; no argument or -1 means the caret's line), `tabSize n` (in spaces).
- `pad "t [r [b [l]]]"` sets a control's padding, or the client area's with id 0, with CSS's rules for fewer values, and answers `l t r b`. Note the two orders: given top-first, answered left-first.
- `tabStop 1|0`; `optUid i`: an item of a list or combo box keeps one number however it moves, made on first ask; `rowHeight`: a row of a list-view, tree-view or list box, in pixels.
- List-views: `lv.order "u1 u2 …"` puts the rows with those uids first, in that order, and the others after as they were, keeping the focus; `lv.uids` answers the uids in row order; `lv.row n` answers a row's cells, joined by `1F`.
- A `KEY` event's `extra` is the id of the control with the focus (0 for the dialog).

## Tool bar and custom draw (added 19 Nov 2026, v0.13.0, as read from oodialog-wasm `d15b927`, v0.22.0)

- `TOOLBAR` controls lie along the top of the client area at its full width, whatever rectangle the program gave, at least 24 px high; the buttons flow left to right and wrap, as the page's `flex-wrap`. Controls under it are not moved. Ops, indexes from 0:
  - `tb.insert at "cmd 1F text 1F style 1F state 1F image"` (at -1: the end); `tb.count`; `tb.indexOf cmd` (-1 for none); `tb.get i` and `tb.byCmd cmd` answer `cmd 1F text 1F style 1F state 1F image`; `tb.setText cmd text`; `tb.setImage cmd n` (kept, not drawn); `tb.setState cmd WORD 1|0`; `tb.has cmd WORD`; `tb.height`.
  - style and state are Windows keywords (style BUTTON SEP CHECK GROUP CHECKGROUP DROPDOWN …; state ENABLED CHECKED PRESSED HIDDEN INDETERMINATE MARKED …), kept in the order given; a word turned on later goes at the end. `tb.get` shows them in that order, and programs print it.
  - A click on an ENABLED button sends `CMD cmd 0`, as a push button. A CHECK button turns CHECKED on and off; a CHECKGROUP button is CHECKED and the others of its run of CHECKGROUP buttons are not. CHECKED or PRESSED draws the button pushed. Images are not drawn: a button shows its text.
- Custom draw of a list-view or tree-view: `cd.on` (the program called customDrawControl). After each time the control is drawn, after it scrolls, and after a check box is ticked, the renderer sends `CD id ROWS rows-in-view` 30 ms later: for a list-view `first last` (row indexes), for a tree-view `item:level item:level …`. The program answers with `cd.paint JSON`: for a list-view `[[uid, [[column or -1 for the whole row, text colour, background, font], …]], …]`, for a tree-view `[[item, text colour, background, font], …]`. `""` leaves a value as drawn; a font is oodWeb's CSS (`[italic] [bold] Npt "Name", sans-serif`). A row keeps its paint until the next answer for it, and moves with its row. No second question is sent before the first is answered; oodWeb always answers, with `[]` if it has nothing.
- `lv.insRow at cells U` answers `index uid`. `tv.kids item` answers the children (item 0: the roots); `tv.order item "h1 h2 …"` puts those children first, in that order, and the others after as they were.
- Not a renderer change, but it reaches the files a renderer stages: oodfiles.js 0.2.0 also gives data files a program names in a string (`"data\Items.txt"`, `"itemsI.inp"` for `ItemsI.INP`) under the spelling written. The Qt runner's `tools/WindowsNames.cls` does the same.
