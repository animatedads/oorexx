/* oodqt_suite.rex -- the whole ooDialog/WASM suite on the Qt6 renderer, in the groups the browser harness uses.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-15.
 *
 *   rexx tools/oodqt_suite.rex --wasm DIR --samples DIR [--designer DIR] [--pdfkit DIR] [--platform offscreen|xcb] [--shots DIR]
 *
 * --wasm      the oodialog-wasm directory (its dist/ must be on REXX_PATH, as for oodqt_test.rex)
 * --samples   upstream ooRexx's samples/windows/oodialog: the --tree for each group, as the README's commands
 * --designer  optional: the ooDialog Designer's tests/gen, run as they are
 * --pdfkit    optional: the directory tools/oodpdfkit.rex of oodialog-wasm made; tests/print runs with it as the tree
 * --platform  offscreen (the default) or xcb, for an X server (DISPLAY), e.g. under xvfb-run
 *
 * The groups: tests/designer and tests/res with no tree; tests/t*.rex and tests/up with the samples;
 * tests/up2 with samples/tutorial; tests/up3 with samples/propertysheet.tabControls; tests/up4 with samples/mouse; tests/up5 with samples/controls/ListView/subitem.editing;
 * tests/up6 SimpleMonthCalendar with samples/simple and PaidHolidays with samples/controls; tests/up7 with samples/resizableDialogs/ResizingAdmin; tests/up8 with samples/controls/ToolTip; tests/up9 with samples/propertysheet.tabControls; tests/up10 customDrawListview with samples/controls/ListView and treeViewCustomDraw with samples/controls/TreeView.
 * Each test runs as oodqt_test.rex runs it.  Exit 0 only if every test passes.
 */
parse arg argline
opts = .stringtable~new
opts["PLATFORM"] = "offscreen"
do while argline \= ""
  parse var argline word value argline
  select
    when word == "--wasm" then opts["WASM"] = value
    when word == "--samples" then opts["SAMPLES"] = value
    when word == "--designer" then opts["DESIGNER"] = value
    when word == "--pdfkit" then opts["PDFKIT"] = value
    when word == "--platform" then opts["PLATFORM"] = value
    when word == "--shots" then opts["SHOTS"] = value
    otherwise do
      .error~lineout("oodqt_suite: unknown argument" word)
      exit 2
    end
  end
end
if \opts~hasIndex("WASM") | \opts~hasIndex("SAMPLES") then do
  .error~lineout("usage: rexx oodqt_suite.rex --wasm DIR --samples DIR [--designer DIR] [--pdfkit DIR] [--platform offscreen|xcb] [--shots DIR]")
  exit 2
end
t = opts["WASM"]"/tests"
s = opts["SAMPLES"]
groups = .array~new
groups~append(.array~of("", files(t"/designer/*.rex") || files(t"/res/*.rex") || files(t"/demo/*.rex") || files(opts["DESIGNER"]"/*.rex")))
groups~append(.array~of(s, files(t"/t*.rex") || files(t"/up/*.rex")))
groups~append(.array~of(s"/tutorial", files(t"/up2/*.rex")))
groups~append(.array~of(s"/propertysheet.tabControls", files(t"/up3/*.rex")))
groups~append(.array~of(s"/mouse", files(t"/up4/*.rex")))
groups~append(.array~of(s"/controls/ListView/subitem.editing", files(t"/up5/*.rex")))
groups~append(.array~of(s"/simple", files(t"/up6/SimpleMonthCalendar.rex")))
groups~append(.array~of(s"/controls", files(t"/up6/PaidHolidays.rex")))
groups~append(.array~of(s"/resizableDialogs/ResizingAdmin", files(t"/up7/*.rex")))
groups~append(.array~of(s"/controls/ToolTip", files(t"/up8/*.rex")))
groups~append(.array~of(s"/propertysheet.tabControls", files(t"/up9/*.rex")))
groups~append(.array~of(s"/controls/ListView", files(t"/up10/customDrawListview.rex")))
groups~append(.array~of(s"/controls/TreeView", files(t"/up10/treeViewCustomDraw.rex")))
if opts~hasIndex("PDFKIT") then groups~append(.array~of(opts["PDFKIT"], files(t"/print/*.rex")))   -- the standby printer, with oodialog-wasm's PDF kit as the tree

runner = .OodQtTest~new
log = .ToolProgress~new("oodqt-suite", runner, "RUN")~logger
runner~useLogger(log)
shots = ""
if opts~hasIndex("SHOTS") then shots = opts["SHOTS"]
passed = 0; total = 0; failed = .array~new
do g over groups
  if g[2]~words == 0 then iterate
  tests = g[2]~space~makeArray(" ")
  runner~run(tests, shots, g[1], opts["PLATFORM"])
  passed += runner~passed
  total += tests~items
  do f over runner~failed; failed~append(f); end
end
log~log(.Log~INFO, "suite on" opts["PLATFORM"]":" passed "of" total "passed")
if failed~items > 0 then log~log(.Log~WARN, "failed:" failed~makeString("L", " "))
exit failed~items > 0

files: procedure                      -- the matching files, each followed by a blank
  use arg pattern
  if pattern == "/*.rex" then return ""         -- no --designer given
  call SysFileTree pattern, "f.", "FO"
  out = ""
  list = .array~new
  do i = 1 to f.0; list~append(f.i); end
  do p over list~sort; out = out p" "; end
  return out

::requires "OodQtTest.cls"
::requires "LogStreamTarget.cls"
