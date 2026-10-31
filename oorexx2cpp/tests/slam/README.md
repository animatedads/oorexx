# SLAM's tests, run against compiled code

Architecture: Tom Dyer. Test cases chosen by SLAM (animatedads/alchemy `packages/oorexx_slam_v0.1`, `04eb3204`),
written by its `unittests` writer. Harness: Claude (Opus 5.5), 2026-10-30.

`groups/` holds SLAM's ooTest groups for the standalone routines of this tree's fixtures: 27 SLAM groups and 27
random-input groups of the same size, for comparison. Each case asserts what the interpreter returned when SLAM ran
it, so the groups are interpreter-checked tests with inputs SLAM chose.

`tests/test_slam_compiled.sh` runs each group twice:
- interpreted, as SLAM wrote it (the routine lifted from its file in this tree). A failure here is DRIFT: SLAM's
  expected value no longer holds, so the group must be written again.
- compiled: the fixture file is built with rx2cpp as a native library (a copy with every `::ROUTINE` public, so the
  library exports the routine under test), and the group's `underTest` finds the routine there. A failure here is
  a difference between rx2cpp and the interpreter.

It needs `OOTEST_ROOT` (an unzipped ooTest snapshot, holding `ooTest.frm` and `framework/`); without it the test
says SKIP.

To write the groups again (from `packages/oorexx_slam_v0.1` in the alchemy repo):

    sh bin/slam_toy.sh unittests /path/to/oorexx2cpp unit_out

then copy the groups whose header says `Unit under test: routine` into `groups/`, with the tree's own path removed
from them.

History: the first compiled run (2026-10-29) agreed on 1,323 of 1,327 assertions; the 4 others were a bug in
SLAM's lifter (it dropped the package's `::OPTIONS`; rx2cpp was right), fixed by SLAM in `cd9bf487`.
