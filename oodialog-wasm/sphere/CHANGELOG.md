# Changelog

## 0.15
- Port v0.28.1: three faults of the demo page corrected; cleanup() in the renderer contract; one lesson.
- State: first test in real browsers, by Josep Maria Blasco.
- Written by Claude (Fable 5.2).

## 0.14
- State article brought to port v0.28.0: 1,157 of 1,182 natives (1,129 at v0.27.0); file dialog customizations.
- Lessons: a field of a directory must not have the name of a Directory method (items, index, start); a rename over a whole file must be read line by line before it is trusted.
- Written by Claude (Fable 5.2).

## 0.13
- State article brought to port v0.27.0: 1,129 of 1,182 natives (1,118 at v0.26.0); the tab owner dialog.
- Renderer contract: TCM_SETCURFOCUS sends the two selection notices.
- Written by Claude (Fable 5.2).

## 0.12
- State article brought to port v0.26.0: KDE Breeze icons stand for the system images of Windows.
- Renderer contract: the kde: image names and the message box icons.
- Written by Claude (Fable 5.2).

## 0.11
- State article brought to port v0.25.0: 1,118 of 1,182 natives (1,098 at v0.24.0).
- Renderer contract: the six NM_ notifications of every control, the *.* subscription, bars added after the dialog is shown.
- Correction: v0.10 named 14 of the missing natives "category and task dialogs". 11 of them are the tab owner dialog; there is no task dialog in ooDialog.
- Written by Claude (Fable 5.2).

## 0.10
- State article brought to port v0.24.0: 1,098 of 1,182 natives (1,033 at v0.23.0).
- Renderer contract: the SCROLLBAR kind, the SB event, and the ops added in v0.24.0.
- Correction: the not-done list still named tool bar, status bar, re-bar, custom draw, scroll bars, getComboBoxInfo, the modeless property sheet and printing, all of which are done and tested. The list is now what is missing at v0.24.0.
- Written by Claude (Fable 5.2).

## 0.9
- State article brought to port v0.23.0: 1,033 of 1,182 natives.
- Renderer contract: the REBAR kind and its rb.* ops; a dialog is kept within reach.
- Written by Claude (Fable 5.2).

## 0.8
- State article brought to port v0.22.0: 955 of 1,182 natives.
- Renderer contract: the TOOLBAR kind and its tb.* ops; custom draw (cd.on, the CD event, cd.paint); lv.insRow U; tv.kids, tv.order; late drawing of long lists.
- Lessons: a test that passed once.
- Written by Claude (Fable 5.2).

## 0.7
- State article brought to port v0.21.0: 881 of 1,182 natives.
- Renderer contract: the STATUSBAR kind and its sb.* ops; lv.order, lv.uids, lv.row; optUid and the other small ops; windowAt; the KEY event's extra.
- Lessons: native coverage stood still for four releases.
- Written by Claude (Fable 5.2).

## 0.6
- State article brought to port v0.20.0 (printing through the estate's oorexx_pdf).
- Renderer contract: deliver.
- Lessons: a test run against a build that was not rebuilt.
- Written by Claude (Fable 5.2).

## 0.5
- State article brought to port v0.19.1 (demo page samples; no change to the renderer contract).
- Lessons: a report from a person with a real browser found a sample that showed nothing; upstream's calculator has no keyboard code.
- Written by Claude (Fable 5.2).

## 0.4
- State article brought to port v0.19.0 (pagedTab; four faults found by the probe and fixed).
- Renderer contract: ra.page, tab.outer, BM_SETSTATE, TCM_SETMINTABWIDTH.
- Written by Claude (Fable 5.2).

## 0.3
- State article brought to port v0.18.0 (tool tips).
- Renderer contract: the tip.* operations, the event kind TT, tv.hit, tv.rect, the notification GETINFOTIP. The op named tip is gone.
- Differences: what tool tips do not do; the dropped list of a combo box is not a window.
- Written by Claude (Fable 5.2).

## 0.2
- Corrected: v0.1 listed ResizingAdmin as done. It was ported only in port v0.17.0. The state article now lists a feature as done only when a test with assertions covers it.
- State article brought to port v0.17.0 (ResizingAdmin, month calendar, the combo box's edit control).
- Renderer contract: ra.init, ra.limits, isDropList, the WM code RASIZEENDED.
- Differences: pagedTab, tool tips.
- Lessons: "shows" is not "works"; the three-double-quotes trap.
- Start article: the other tasks around the port, among them the work that adds the newer Microsoft controls to ooDialog.
- The sphere is now built by tools/oodsphere.py from sphere-src/articles.py; evidence lines are found in the committed files.
- Written by Claude (Fable 5.2).

## 0.1
- First version: nine articles (start, build and test, renderer contract, seams, differences from Windows, harness, porting a native, state at v0.16.0, lessons), with line-level evidence against animatedads/oorexx commit 39a1eec. Written by Claude (Fable 5.2).
