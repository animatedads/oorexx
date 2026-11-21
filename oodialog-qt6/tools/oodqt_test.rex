#!/usr/bin/env rexx
/* oodqt_test.rex -- run ooDialog test programs on the Qt6 renderer, offscreen
 * by default; --platform xcb runs them on an X server (DISPLAY), e.g. under xvfb-run.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14.
 *
 *   rexx tools/oodqt_test.rex [--shots DIR] [--tree DIR] test.rex [test.rex ...]
 *
 * Each program runs in a fresh directory under TMPDIR, as the page runs it in a
 * fresh /home/rexx: the program, its TEST.files/, and ooDialog.cls, oodWeb.cls and
 * ooShapes.cls.  --tree DIR adds a whole directory (upstream's samples), as the
 * browser harness's --tree does.  /home/rexx in the steps and the .expect means
 * that directory.
 *
 * The same tests as the browser harness (oodialog-wasm/tools/oodtest.py):
 * test.steps beside a test drives it (played by the renderer, OODQT_STEPS),
 * and its output must equal test.expect when that exists.  Each program runs
 * as a separate rexx process with a 90-second limit.
 * Needs on REXX_PATH: oodialog-qt6/src (js.cls), oodialog-wasm/dist
 * (ooDialog.cls, oodWeb.cls, ooShapes.cls), and the alchemy logging packages
 * (oorexx_logging_stream_target_v0.1/src) for the progress log; liboodqt.so
 * on LD_LIBRARY_PATH.  Exit 0 only if every test passes.
 */
parse arg argline
shots = ""
tree = ""
platform = "offscreen"
tests = .array~new
do while argline \= ""
  parse var argline word argline
  if word == "--shots" then parse var argline shots argline
  else if word == "--tree" then parse var argline tree argline
  else if word == "--platform" then parse var argline platform argline
  else tests~append(word)
end
if tests~items == 0 then do
  .error~lineout("usage: rexx oodqt_test.rex [--shots DIR] [--tree DIR] [--platform offscreen|xcb] test.rex [test.rex ...]")
  exit 2
end
runner = .OodQtTest~new
runner~useLogger(.ToolProgress~new("oodqt-test", runner, "RUN")~logger)
exit runner~run(tests, shots, tree, platform)

::requires "OodQtTest.cls"
