# Articles of the oodialog-wasm sphere. Architecture: Tom Dyer. Written by Claude (Fable 5.2).
# Each article: id, title, summary, section, topics, and lists of plain sentences.
S = "oodialog-wasm"
VERSION = "0.6"            # the sphere's version; raise it for a material change
PORT = "0.20.0"             # the version of the port the articles were checked against
REPO = "animatedads/oorexx, branch oodialog-wasm, directory oodialog-wasm/"

def art(id, title, summary, section, topics, **lists):
    d = {"kind": "article", "id": id, "version": VERSION, "sphere": S, "title": title, "summary": summary,
         "authority": "implementation-record", "section": section, "topics": topics}
    d.update(lists)
    d["provenance"] = []
    return d

ARTICLES = [
art("ops.oodialog-wasm.start",
    "Start here: what ooDialog/WASM is and where it lives",
    "ooDialog/WASM runs unchanged ooDialog programs in a web browser on Josep Maria Blasco's ooRexx/WASM runtime. "
    "Upstream's Rexx classes are kept. Only the Windows DLL is replaced: by a native layer in Rexx (oodWeb.cls) and a page runtime in JavaScript (oodialog-web.js). "
    "The code is in " + REPO + ". The README.md there is the current state; this sphere explains how the parts fit and what other tasks may rely on.",
    "getting-started", ["overview", "layout", "ownership"],
    facts=[
        "Architecture: Tom Dyer. Code: Claude (Fable 5.2). Runtime: oorexxwasm 0.2.4 (ooRexx 5.3.0) and its js.cls, by Josep Maria Blasco.",
        "Upstream: ooDialog trunk, SourceForge oorexx code-0 r13513. About 11,700 lines of Rexx classes over 104,000 lines of C++, joined by about 1,180 native entry points.",
        "Programs keep ::requires \"ooDialog.cls\". Three files go into the interpreter's file system: ooDialog.cls, oodWeb.cls, ooShapes.cls. They are in dist/.",
        "tools/oodgen.rex reads upstream's *.cls and writes dist/ooDialog.cls. Every external \"LIBRARY oodialog fn\" becomes a forward to .oodn~fn(self, MESSAGENAME, argumentArray).",
        "src/oodWeb.cls is the native layer. .oodn is its one object. A native that is not ported raises SYNTAX 98.900 and names itself.",
        "src/oodialog-web.js is the page runtime: dialogs and controls as DOM elements, a subset of Win32 control messages, events back to Rexx. The build embeds it in oodWeb.cls.",
        "src/patches.txt replaces or drops the few upstream members that must run in the class's own scope (init methods, the calendar's date attribute).",
        "src/oodExtras.cls holds classes of the port that need ooDialog's own classes (OodFileDialog). The build appends it to ooDialog.cls.",
        "The lane of this work in the agent mailbox is oodialog_wasm.",
        "Other tasks around it: the designer (writes ooDialog programs), the Qt6 renderer (answers the renderer contract outside a browser), the binary resource reader (plugs into the resource provider), and ChatGPT's work that adds the newer Microsoft controls to ooDialog itself. When upstream's classes gain a control, the generator carries the new class over unchanged and each of its natives raises SYNTAX 98.900 until it is ported.",
    ],
    procedure=[
        "Read ref.oodialog-wasm.renderer-contract before writing another renderer or a tool that drives the page.",
        "Read ref.oodialog-wasm.seams before building on top of the port (designer, resource reader, system classes).",
        "Read ops.oodialog-wasm.differences before judging a behaviour as a fault.",
        "Read ref.oodialog-wasm.harness before running or writing tests.",
        "Read ops.oodialog-wasm.port-a-native before adding to the native layer.",
    ],
    invariants=[
        "Upstream's Rexx is not edited by hand. A change goes into the generator, patches.txt or the native layer.",
        "An upstream example used as a test is copied unchanged.",
        "dist/ is build output. Edit src/ and run the build.",
    ]),

art("ops.oodialog-wasm.build-and-test",
    "Build the three class files and run the tests",
    "One Rexx tool builds dist/. One Python tool runs programs in headless Chromium against the built files. "
    "A change is finished only when the whole suite passes on the final build, checked before the commit.",
    "getting-started", ["build", "test", "procedure"],
    procedure=[
        "Kit: Node with the npm package oorexxwasm 0.2.4 (it provides the command rexx); the browser runtime oorexxwasm-web-0.2.4 unpacked into site/; Python 3 with Playwright and Chromium; upstream ooDialog r13513 unpacked as upstream/ (examples in upstream/examples).",
        "Build, from the project directory: rexx tools/oodbuild.rex",
        "Run the core tests: python3 tools/oodtest.py --tree upstream/examples tests/t*.rex tests/up/*.rex tests/designer/*.rex",
        "Run the other groups, each with its own tree: tests/up2 with upstream/examples/tutorial; tests/up3 with upstream/examples/propertySheet.tabControls; tests/up4 with upstream/examples/mouse; tests/up5 with upstream/examples/controls/ListView/subitem.editing; tests/up6/SimpleMonthCalendar.rex with upstream/examples/simple; tests/up6/PaidHolidays.rex with upstream/examples/controls; tests/up7 with upstream/examples/resizableDialogs/ResizingAdmin; tests/res/t07_resdialog_binary.rex with no tree.",
        "Read every summary line. All must say 0 failed. Only then commit.",
    ],
    invariants=[
        "The suite is run on the final build. A version-string change is a new build.",
        "A test that passes one run in five is a failing test. Repeat a timing-sensitive test several times before trusting it.",
        "The README.md states the test count and the version it was measured on.",
    ],
    lessons=[
        "v0.13.0 was pushed with a failing check because the result of the last run was not read before the commit. The fault (an event method run inside another thread's sleep) reached another task.",
    ]),

art("ref.oodialog-wasm.renderer-contract",
    "The renderer contract: what the native layer asks of the page, and what the page sends back",
    "oodWeb.cls talks to a renderer through one object, window.__ood in the browser. Any renderer (the browser page, the Qt6 renderer) that answers the same calls and sends the same events can run the same ooDialog programs. "
    "The reference implementation is src/oodialog-web.js. This article names the calls and the rules; the source is the authority for each argument.",
    "reference", ["renderer", "contract", "events", "qt6"],
    calls=[
        "create(spec, ctrls): make a dialog (hidden) with its controls. Answers the dialog's key, a small whole number.",
        "addControl(key, spec): add one control to a dialog that exists.",
        "show(key, how) and destroy(key).",
        "sub(key, id, code): the program has connected the WM_COMMAND notification code of control id.",
        "msg(key, id, msg, wParam, lParam): a Win32 control message (BM_, EM_, LB_, CB_, PBM_, TBM_, LVM_ ... as numbers). Answers the message's result as a string.",
        "op(key, id, name, a, b, c): everything that is not a Win32 message. id 0 is the dialog itself. Answers a string.",
        "msgBox(token, text, title, buttons, icon), popupMenu(token, x, y, data), setMenu(key, data).",
        "measure(text, fontName, fontSize), screen(), image(name, url), hasImage(name).",
        "setHandler(fn): the renderer calls fn(key, kind, id, code, extra) for each event. In the browser fn only puts the event in a queue.",
    ],
    op_families=[
        "Plain names act on any window: rect, clientRect, move, size, show, hide, enable, setText, getText, focus, exists, setParent, grandChild, tabStops, bitmapPos, isDropList.",
        "ra.init and ra.limits: ResizingAdmin. ra.init takes one JSON text: def (the four default edges), ctrls (rows of id and four edges), min, max, ended. An edge is [pinType, pinToEdge, pinToID] with pinType S, P, ML or MT. The renderer keeps each control's first rectangle and, whenever the dialog's client area changes size, places every control by the arithmetic of raLayout in the reference source.",
        "lv.* list-view, tv.* tree-view, tab.* tab control, ud.* up-down, dtp.* date-time picker, mc.* month calendar.",
        "gdi: drawing on a window. op(key, id, \"gdi\", verb, values, style). Verbs: line rect arc angleArc pixel getPixel fillRect clear extent text flood image scroll size ownerDraw.",
        "ra.page, since v0.19.0: op(key, tabId, \"ra.page\", childKey) names an embedded dialog as a page of that tab control. After every ResizingAdmin layout of the dialog, each page is moved and sized to the tab's display area; if the page has its own ra.init definition, it is laid out too. An embedded dialog that is sized by the size op and has a definition is laid out at once.",
        "tab.outer: the whole tab control as \"l t r b\" in the dialog's client area. tab.rect is its display area in the same coordinates. Rexx computes calcDisplayRect from the difference of the two. Control messages new in v0.19.0: BM_SETSTATE (0xF3), bit 4 of BM_GETSTATE (pushed), TCM_SETMINTABWIDTH (0x1331, answers the width before or -1).",
        "deliver, since v0.20.0: a call of the page object like msgBox, not an op: deliver(name, mime, hex, title). hex is the file's bytes as hexadecimal digits. The renderer hands the file to the user: show it, and let the user print, open or save it. Answer the number of bytes as a string. Rexx side: .oodn~deliver(path, title, mime).",
        "mouseSub and mouse: the Mouse class. mouse verbs: capture release getCapture state cursor.",
        "tip.*: tool tips, since v0.18.0. The id is the tool tip's ID, not a control's: route tip.* before looking the id up as a control. tip.add takes one JSON text {key, host, rect, text}: host is a control's id or 0 for the dialog; rect is null (the whole window) or [l, t, r, b] in that window's client area; text null means the text is asked from the program. Others: tip.del(key), tip.text(key, text; one separator character means asked), tip.relay(hostId, 1|0), tip.count, tip.delay(ms), tip.maxWidth(px), tip.title(text), tip.active(1|0), tip.events(words), tip.show(text), tip.pos(x, y in screen pixels), tip.pop, tip.shown (toolKey, separator, text; empty if no tip), tip.tree(treeViewId).",
        "The renderer decides when a tip is due: the pointer rests on a tool for the delay. Fixed text: show the box, then send TT SHOW if tip.events names SHOW. Asked text: send TT NEEDTEXT; the program answers with tip.show. An empty text shows nothing. tip.pop ends the tip; if the pointer is still on the tool, the tip is due again after the delay. A tree-view named by tip.tree asks the text of the item under the pointer with NOTIFY GETINFOTIP (extra: the item); the answer is tip.show on tool tip ID 60000 + the tree-view's id.",
        "The op named tip (the element's title) is gone since v0.18.0. tv.hit(x, y) answers \"item LOCATION\"; tv.rect(item, textOnly) answers \"l t r b\" in the tree-view's client area.",
    ],
    events=[
        "The renderer sends (key, kind, id, code, extra). Kinds: CMD (WM_COMMAND), NOTIFY (a named control notification), MSGBOX (a message box was answered), CTX (context menu), KEY (a connected key), TT (a tool tip: id is the tool tip's ID, code is SHOW, POP, NEEDTEXT or RELAY, extra is the tool's key; for RELAY the key, x and y joined by the separator), WM (a window message: RESIZE, SIZEMOVEENDED, MOVE, and RASIZEENDED when a ResizingAdmin dialog with wantSizeEnded stops being sized), MOUSE (a Mouse class event), GC (RETURN, ESCAPE, TAB or loss of focus in a control placed on another control).",
        "Events are queued. Rexx takes them one at a time with .js~nextEvent. The renderer must never call into Rexx directly.",
    ],
    invariants=[
        "The separator character is hex 1F. Lists of values travel as one string joined by it. A single value can itself contain it only where the reference source shows that (list rows, tree options): split on the count of fields the call defines, not on every separator.",
        "A window handle is \"0x\" followed by 16 hex digits of key * 65536 + id.",
        "A renderer that does not know an op answers the empty string. It must not raise an error.",
        "Coordinates are pixels. Client-area coordinates are from the top left of the window's client area.",
        "A connected MOUSEWHEEL does not scroll the control by itself. The program scrolls it.",
        "After setText, a multi-line edit shows its start, with the caret at 0.",
    ],
    procedure=[
        "To support a new op in another renderer: find the op name in src/oodialog-web.js, read its case, implement the same answer string.",
        "To learn what changed between two versions: read the commit messages of the branch. Each one lists new ops and events.",
    ]),

art("ref.oodialog-wasm.seams",
    "Seams: the places where other work plugs in",
    "Four seams let other tasks build on the port without editing it: a resource provider for binary Windows resources, the list of live dialogs for system classes, the Windows file-name helper for loaders, and the file dialog class.",
    "reference", ["seams", "resources", "designer", "winsystm", "files"],
    seams=[
        "Binary resources (.dll, .res): the port does not read them. Set .oodn~resourceProvider to an object that answers dialogTemplate(library, id) and menuTemplate(library, id). The shapes are in the comment above the attribute resourceProvider in src/oodWeb.cls. Test: tests/res/t07_resdialog_binary.",
        "Live dialogs: .oodn~windows answers an array of the ooDialog objects of the dialogs now shown, oldest first. A system-classes file (WindowsManager, WindowObject, MenuObject for this machine) builds on it and on ooDialog's own API. Test: tests/t14_owned.",
        "Windows file names: site/oodfiles.js, function oodFiles.windowsNames(files), called by the page before rexx.run. For every ::requires or CALL name written with a backslash it adds the file again under that literal name, in each directory from which the name resolves the Windows way. Programs are not changed. Test: tests/t16_winnames.",
        "File dialog: class OodFileDialog in src/oodExtras.cls, over the WASM machine's file system. FileNameDialog, OpenFileDialog, SaveFileDialog and BrowseForFolder all use it.",
        ".application~srcDir is the directory of the program that was started (the bottom of the call stack), also when oodWeb.cls is in another directory. Test: tests/t17_srcdir.",
        "The browser clipboard is reached through .js~page of the runtime's js.cls. The port itself does not use it.",
    ],
    invariants=[
        "winsystm.cls and OLE are Windows system libraries, not ooDialog. The port does not provide them. The sweep marks programs that need them as outside.",
        "The designer and the Qt6 renderer are other tasks' work. Their programs in tests/designer are copies kept as a contract test; they are not edited here.",
    ]),

art("ops.oodialog-wasm.differences",
    "Where the port differs from ooDialog on Windows, by design",
    "These differences come from the browser, not from faults. Check this list before reporting a behaviour as a bug.",
    "operations", ["differences", "threads", "drawing", "limits"],
    differences=[
        "Threads: Windows runs each event method on its own thread. Here event methods run on the thread that takes the page's events (the one inside execute). msSleep on that thread handles the other events while it waits, so a method that loops and sleeps does not freeze its dialog. msSleep on any other thread just sleeps. A loop that never calls msSleep holds its dialog.",
        "After a dialog has been closed, msSleep inside one of its event methods returns at once, so the program can end.",
        "A dialog with an ownerDialog ends when its owner ends.",
        "Drawing: a device context is a canvas over the window. What is drawn stays until it is cleared; Windows loses it at the next repaint. Lines are anti-aliased, so a flood fill can leave a thin rim. A bitmap brush is a plain colour.",
        "connectDraw: the draw method is asked when the dialog is shown and when the program redraws the control, not on every repaint.",
        "The pointer cannot be moved or confined: setCursorPos and clipCursor do nothing.",
        "File and folder dialogs browse the WASM machine's file system. COM calls answer S_OK and do nothing. A refused file (onFileOk) closes the dialog and shows it again.",
        "There are no printers. A printer root in BrowseForFolder is ignored.",
        "The month calendar shows one month and selects one day.",
        "ResizingAdmin: A dialog made larger than the browser window is not scaled down again.",
        "Tool tips are drawn by the page since v0.18.0. Only the INITIAL delay acts: a tip stays until the pointer leaves its tool. Balloon style, icon, margins, colours and tracking tool tips are accepted and not shown. LINKCLICK is never sent. RELAY is sent for pointer moves only. A touch screen shows no tips.",
        "The dropped list of a combo box belongs to the browser and is not a window. getComboBoxInfo is not ported.",
        "A list box entry cannot show a tab character. With tab stops set, the entry is shown filled out to each stop; its text stays as the program gave it.",
        "A dialog larger than the browser window is scaled down to fit.",
        "Events the port accepts but never produces print one line: \"... is connected but is not produced yet\". The program goes on.",
    ],
    invariants=[
        "A difference that is not in this list or in the README is to be treated as a fault and reported to the lane oodialog_wasm.",
    ]),

art("ref.oodialog-wasm.harness",
    "The test harness: test files, steps, the sweep and the probe",
    "tools/oodtest.py runs a Rexx program in headless Chromium, drives the page with steps, and compares the program's output. It also has two survey modes over all upstream examples.",
    "reference", ["harness", "tests", "sweep", "probe"],
    files=[
        "NAME.rex: the program. NAME.steps: what to do on the page, one step a line. NAME.expect: the lines the program must print (optional). NAME.files/: extra files for the program's directory, sub-directories allowed.",
        "--tree DIR puts every file of DIR into the program's directory first. Use it for upstream examples that need their .rc, .h and bitmap files.",
        "The program runs in /home/rexx of the WASM machine.",
    ],
    steps=[
        "wait SELECTOR: until the element is visible.",
        "click SELECTOR. fill SELECTOR => TEXT. select SELECTOR => VALUE. press KEY. type TEXT (into what has the focus).",
        "mouse down|move|up|wheel SELECTOR @ DX DY [DELTA]: a real pointer, DX DY from the element's top left corner.",
        "sleep MILLISECONDS. shot NAME (a screenshot into shots/).",
        "eval JAVASCRIPT: run it and log the answer. expect JAVASCRIPT ==> VALUE: the answer must equal VALUE.",
    ],
    pass_rules=[
        "A test passes when every step succeeds, the program ends by itself, and its output contains the .expect lines.",
        "An unknown step fails the test.",
        "Selectors use the page's class names: .ood-dlg dialog, .ood-c control, .ood-def default button, .ood-msgbox message box, .ood-lv list-view, .ood-mc month calendar, .ood-child a dialog shown inside another.",
    ],
    surveys=[
        "--sweep DIR: starts every example that requires ooDialog.cls, each from its own directory, and writes sweep.tsv. Verdicts: shows (a dialog appeared), ended, message (only a message box), native:NAME (stopped at a native not ported), error:TEXT, component (a part of a larger program started alone; it fails the same way on Windows), outside (needs winsystm.cls or OLE).",
        "--poke DIR FROM TO: for each example that shows something, presses every control and then closes everything, and writes poke.tsv. Verdicts: clean, event-not-produced, or the problem found. It proves that nothing fails; it does not prove that what is shown is right.",
    ],
    invariants=[
        "Each test runs in a fresh page. Tests must not depend on today's date; compute dates in the step.",
        "Results that were measured on an older version are labelled with that version.",
    ]),

art("ops.oodialog-wasm.port-a-native",
    "How to port one native function",
    "A native is ported in four moves: read what the C++ does, write the Rexx method in oodWeb.cls, add what the page must do in oodialog-web.js, and prove it with an upstream example run unchanged.",
    "operations", ["procedure", "natives", "porting"],
    procedure=[
        "Find the need: run the example; the error names the native, for example \"native function MC_GETMINRECT\".",
        "Read the C++: grep -a -n \"RexxMethod.*mc_getMinRect\" upstream/ooDialog/*.cpp. Use grep -a: some of the C++ files are not plain ASCII and plain grep skips them silently. tools/cfn.py --sigs writes every signature to dist/sigs.txt.",
        "Read how upstream's Rexx calls it: grep the name in dist/ooDialog.cls. One native can serve several methods; the second argument tells which.",
        "Write the method in src/oodWeb.cls: ::method NAME unguarded, then use arg self_, msg, a. self_ is the Rexx object, msg the upper-case method name, a the argument array.",
        "Reach the page with self~op(self_, opName, a, b, c) for a control object or self~ctlOp(dialogState, id, opName, a, b, c).",
        "Add the op to src/oodialog-web.js. Keep the answer a string.",
        "Build. Copy the upstream example into a tests/upN directory, write its .steps, run it.",
        "Run the whole suite, then update README.md (counts, what is new, what is not done).",
    ],
    invariants=[
        "An optional argument is tested with a~hasIndex(n). a~last of an empty array is .nil: loop to a~size.",
        "The default NUMERIC DIGITS is 9. Handles and times need more: set numeric digits in the method, or keep numbers small.",
        "A .Rect given to setWindowPos is a point / size rectangle: right and bottom are the width and height.",
        "Return what the C++ returns (0, .true, a .Rect ...). Programs test these values.",
        "Do not stub a native to return success without doing the work, unless the work is impossible in a browser; then say so in the README.",
    ]),

art("ref.oodialog-wasm.state",
    "State at v" + PORT + " and where the current state is recorded",
    "This article is a snapshot. The current figures are always in README.md of the project, with the version they were measured on; sweep.tsv and poke.tsv hold the per-example results.",
    "reference", ["state", "coverage", "not-done"],
    snapshot=[
        "Version 0.20.0, 17 November 2026.",
        "Natives ported: 688 of 1,182. 12 of the 43 added in v0.18.0 accept their call and do nothing.",
        "Tests: 49 of 49 pass in headless Chromium. 33 of them are upstream examples or the designer's programs, run unchanged.",
        "Sweep of the 140 upstream examples: 79 show their dialog, 7 run to the end, 9 show only a message box, 5 stop at a native not ported, 9 stop on an error (8 of them wait for a reader of binary resources), 24 are components, 7 are outside ooDialog.",
        "Probe at v0.19.0, 88 examples: 73 clean, 11 connect an event that is not produced, 4 with a problem, none of them in the port's own code. This run found four faults of the port in examples the sweep called shows; all four are fixed in v0.19.0.",
        "\"shows\" in the sweep means a dialog appeared. It does not mean every feature of the example works. Only an example that is a test (with steps and assertions) is known to work.",
    ],
    done=[
        "Dialogs: UserDialog, RcDialog (.rc and .h files), ResDialog through the resource provider, ControlDialog, property sheets and wizards, owned dialogs, message boxes, standard dialogs and routines.",
        "Controls: buttons, check boxes, radio buttons, group boxes, statics, images, edits, list boxes, combo boxes, progress bars, list-views, tree-views, tabs, up-downs, track bars, date-time pickers, month calendars.",
        "Menus: menu bars and popup menus, from scripts and through the resource provider.",
        "Resizing: ResizingAdmin (pin definitions, size limits, wantSizeEnded) since v0.17.0, pagedTab since v0.19.0; DlgAreaU with connectResize since v0.9.",
        "Drawing, bitmap buttons and animation, the Mouse class, in-place editing in a list-view (edit, drop-down list, editable combo box), list box tab stops, fonts.",
        "Tool tips since v0.18.0: tools that are windows or rectangles, fixed and asked text, NEEDTEXT SHOW POP RELAY, ToolInfo, manageAtypicalTool, a tree-view's getToolTips with GETINFOTIP.",
        "Printing since v0.20.0: oodPrint.cls makes a PDF with the estate's oorexx_pdf and the page hands it to the user (Print, Open, Save). A list-view as a table, a text, a report of the program, any file. Not checked in a real browser.",
        "File dialogs and shell dialogs over the WASM machine's file system.",
    ],
    not_done=[
        "Tool bar, status bar, re-bar; custom draw; scroll bars as controls.",
        "getComboBoxInfo (the parts of a combo box as windows); tracking tool tips.",
        "ControlDlgInfo and the tab owner dialogs.",
        "connectActivate, connectHelp, connectPosChanged, connectResizing (accepted, not produced).",
        "Image-list icons are not drawn; ResourceImage needs images from a binary resource.",
        "A modeless property sheet; wizard header and watermark images.",
        "The CommonDialogCustomizations controls of the shell dialogs.",
        "Printing. The estate's oorexx_pdf package is native ooRexx and is the planned stand-by printer: write a PDF into the WASM file system and offer it for download or the browser's print. Not started.",
        "Not run on a real phone or on the public Playground; the demo page is not hosted.",
    ],
    invariants=[
        "When this article and README.md disagree, README.md is right and this article needs a new version.",
        "A feature is listed as done only when a test with assertions covers it.",
    ]),

art("ops.oodialog-wasm.lessons",
    "Lessons from the port: faults made and how each is now prevented",
    "Each lesson is a fault that happened in this work, its cause, and the rule that prevents it. They are here so that the next task does not repeat them.",
    "operations", ["lessons", "faults", "method"],
    lessons=[
        "A build was pushed with a failing test. Cause: the last run's result was not read. Rule: read every summary line on the final build before the commit.",
        "A source file was corrected and the test was run without a build. The test ran the old file from dist and showed nothing, because an error in an event method is a message box, not a line of output. Half an hour went on the wrong cause. Rule: build before every test run; when an event method seems to do nothing, look at the page for a message box first.",
        "The probe was not run for three releases. In that time four faults sat in examples the sweep called shows; one put a tab control's pages at the dialog's corner. Rule: run the probe on every release, not only the sweep.",
        "A test of this project called calcDisplayRect with an empty rectangle. Windows programs give it the tab's windowRect. The test passed and the Windows idiom failed. Rule: a test of this project uses the calls in the form the upstream examples use.",
        "A person with a real browser found in five minutes that the menu sample showed nothing when its items were chosen, and that typing into the calculator did nothing. The second is upstream's own behaviour: calculator.rex has no keyboard code and a read-only display. Rule: a sample must show the result of every action it offers; and when a report differs from upstream's code, read upstream's code before changing the port.",
        "msSleep was changed to handle events on any thread. An event method that waits for an animation thread could then run inside that thread's own sleep and wait for ever. Rule: only the thread that takes the page's events may handle events while it sleeps.",
        "The harness ignored a step it did not know, so a misspelt step passed. Rule: an unknown step fails.",
        "The first sweep counted message boxes as dialogs and ran examples from the wrong directory. Rule: each example runs from its own directory; a message box has its own verdict.",
        "Three of four \"does not end\" results were faults of the probe, not of the port. Rule: before reporting a fault found by a tool, reproduce it by hand.",
        "Two \"problems\" were parts of a larger program started alone. Rule: read how the example is meant to be started before fixing it.",
        "A test used today's date and would have failed next month. Rule: compute dates in the step.",
        "Plain grep skipped a C++ file that is not plain ASCII. Rule: grep -a on upstream's C++.",
        "Rexx traps met: \"a\"x is a hex literal, so write \"a\" || x; a name directly followed by ( is a function call; LABEL is a keyword in DO; d2x fails on a negative number; arithmetic above 9 digits needs NUMERIC DIGITS; one EXPOSE line only; a~last of an empty array is .nil.",
        "The other tasks could not know what had changed, because the state was only in this chat, the README and mailbox messages. Rule: this sphere is kept current, and each release is announced in the lane with the new ops and events.",
        "Version 0.1 of this sphere listed ResizingAdmin as done. It was not ported at all: its examples showed a dialog, the sweep said \"shows\", and the claim was written from that. Rule: a feature is listed as done only when a test with assertions covers it; \"shows\" is not \"works\".",
        "A Rexx string that begins with a quoted word, written as three double quotes, does not parse the way it reads. Rule: put a text with double quotes inside single quotes: \'\"\'name\'\" is not an edge\'.",
    ],
    invariants=[
        "A lesson is added when a fault is found, in the same change that fixes it.",
    ]),
]

# Evidence: (article id, file of the project, a text found on the first cited line, lines cited, claim).
EVIDENCE = [
    ("ops.oodialog-wasm.start", "README.md", "## What it is", 24, "The parts of the port and their roles."),
    ("ops.oodialog-wasm.build-and-test", "README.md", "## State on", 20, "The test count and the version it was measured on."),
    ("ref.oodialog-wasm.renderer-contract", "src/oodialog-web.js", "  ood.op = function", 6, "op(key, id, name, a, b, c) is the entry for everything that is not a Win32 message."),
    ("ref.oodialog-wasm.renderer-contract", "src/oodialog-web.js", "  ood.msg = function", 6, "msg(key, id, msg, w, l) is the entry for Win32 control messages."),
    ("ref.oodialog-wasm.renderer-contract", "src/oodialog-web.js", "  const SEP = ", 1, "The separator character is hex 1F."),
    ("ref.oodialog-wasm.renderer-contract", "src/oodialog-web.js", "  function gdi(dlg", 5, "The gdi verbs and the style fields."),
    ("ref.oodialog-wasm.renderer-contract", "src/oodialog-web.js", "  function raLayout(dlg)", 25, "The ResizingAdmin arithmetic."),
    ("ref.oodialog-wasm.renderer-contract", "src/oodialog-web.js", "  /* ---- Tool tips ----", 14, "The tool tip operations and events."),
    ("ops.oodialog-wasm.differences", "README.md", "## Tool tips", 30, "What tool tips do and where they differ from Windows."),
    ("ref.oodialog-wasm.renderer-contract", "src/oodialog-web.js", "  /* ---- Handing a file to the user (the standby printer) ----", 8, "deliver: what the page does with a file."),
    ("ref.oodialog-wasm.state", "README.md", "## Printing (the standby printer)", 20, "What printing is here and what it needs."),
    ("ref.oodialog-wasm.seams", "src/oodWeb.cls", "::attribute resourceProvider unguarded", 1, "The resourceProvider attribute; the shapes are in the comment above it."),
    ("ref.oodialog-wasm.seams", "src/oodWeb.cls", "::method windows unguarded", 10, ".oodn~windows answers the live dialogs, oldest first."),
    ("ref.oodialog-wasm.seams", "site/oodfiles.js", "// oodfiles.js", 17, "windowsNames(files) and its rules."),
    ("ref.oodialog-wasm.seams", "src/oodWeb.cls", "::method app_srcDir_atr unguarded", 16, "srcDir is taken from the bottom frame of the call stack."),
    ("ops.oodialog-wasm.differences", "src/oodWeb.cls", "::method msSleep_rtn unguarded", 24, "msSleep handles events only on the event thread; other threads sleep."),
    ("ops.oodialog-wasm.differences", "src/oodWeb.cls", "::method finishOwned unguarded", 10, "An owned dialog is finished with its owner."),
    ("ref.oodialog-wasm.renderer-contract", "src/oodialog-web.js", "  function raPages(dlg)", 12, "The pages of a paged tab take its display area after each layout."),
    ("ref.oodialog-wasm.harness", "tools/oodtest.py", "raise Exception('unknown step: '", 1, "An unknown step fails the test."),
    ("ref.oodialog-wasm.harness", "tools/oodtest.py", "outside = re.search(", 10, "The sweep verdicts outside and component."),
    ("ops.oodialog-wasm.port-a-native", "README.md", "## What it is", 14, "The generator redirects every external native to .oodn."),
    ("ref.oodialog-wasm.state", "README.md", "## State on", 50, "The state section with counts."),
    ("ops.oodialog-wasm.lessons", "src/oodWeb.cls", "::method onPumpThread unguarded", 6, "onPumpThread: the rule that came from the msSleep race."),
    ("ops.oodialog-wasm.lessons", "README.md", "## ResizingAdmin", 16, "ResizingAdmin was not ported until v0.17.0."),
]
