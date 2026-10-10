/* flags reach the interpreter, and 4 activities keep exact counts on both kinds */
say "ADD  guarded?" .Counter~method("ADD")~isGuarded
say "GADD guarded?" .Counter~method("GADD")~isGuarded
say "CURRENT guarded? (default)" .Counter~method("CURRENT")~isGuarded
do sel over .array~of("ADD", "GADD")
  c = .Counter~new(0)
  r = .Runner~new
  msgs = .array~new
  do 4; msgs~append(r~start("RUN", c, sel, 25000)); end
  do m over msgs; m~result; end
  say sel "total (expect 100000):" c~current
end
::requires 'rx2cpp_threads' library
::class Runner
::method run unguarded
  use arg c, sel, k
  do k; c~send(sel, 1); end
  return 0
