# Changelog

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
