/* catchprobe.rex -- exit 0 if this ooRexx runs CATCH and FINALLY (kitcheck.rex).
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-23. */
src = .array~of('s = ""', 'do', '  x = 1 / 0', 'catch syntax', '  s = s "caught"', 'finally', '  s = s "finally"', 'end', 'return s~strip')
signal on syntax name unknown
r = .routine~new("probe", src)~call
if r == "caught finally" then exit 0
exit 1
unknown:
exit 1
