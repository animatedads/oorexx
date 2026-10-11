# rxinspect: source map from the interpreter's own objects (experiment)

Idea (Tom Dyer): do not parse Rexx to find code units. Make a temporary copy of the file with
`::class __RXP` and `::method main` placed in front. The top-level program then becomes the body of `main`
(compiled, never run) and the original directives follow and end it by themselves. Let ooRexx compile that
copy and read everything back as objects: `Package~classes/routines/publicClasses/publicRoutines/importedPackages/
definedMethods/digits/fuzz/form/prolog`, `Class~methods/superclass/isAbstract/queryMixinClass`,
`Method~source/isPrivate/isPackage/isProtected/isGuarded/isAttribute/isConstant`, `Routine~source`.
Visibility is metadata on the object; nothing is made public or rewritten. Syntax errors come from the interpreter.

Rules (all of them): (1) a `#!` first line is blanked to a comment, same line count; (2) the two wrapper lines are
skipped when mapping lines back; (3) line ranges come from locating each `~source` block in the copy.

Run: `rexx rxinspect.rex file.rex` -> TSV: package / requires / prologue / class / method / routine rows,
with start and end line in the ORIGINAL file.

Findings:
- `.Package~new(name, lines)` on the raw file RUNS the prologue (proved: its SAY output appears at creation).
  The wrapper is what prevents that.
- ooRexx 5.3 demo corpus: 37 of 42 files map completely (classes, methods, routines, prologue range, options).
  The 5 failures are `::REQUIRES` files not installed (rxregexp.cls, socket.cls); the interpreter reports them,
  so requires resolution needs no code of ours either.
- Prologue end vs rx2cpp's RxHostSplit first-directive line: same on all 28 comparable programs; the 6 one-line
  differences are trailing blank lines that `Method~source` trims.
- Limits: `::REQUIRES` files are loaded (their prologues run) while inspecting; `::method x class` methods are not
  listed yet; identical duplicate method bodies are matched in order.
