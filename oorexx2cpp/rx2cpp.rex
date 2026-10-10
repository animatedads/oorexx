/* ooRexx implementation of constrained Rexx-to-native C++17 precompiler.
   Self-compilation is a future coverage milestone, not currently supported. */
parse arg input output
if input == '' | output == '' then do
  say 'Usage: rexx rx2cpp.rex source.rex output.cpp'
  exit 64
end
if input == output then do
  say 'rx2cpp: input and output paths must differ'
  exit 64
end
signal on syntax name compilerError
signal on error name compilerError
signal on failure name compilerError
existing = stream(input, "C", "QUERY EXISTS")
if existing == "" then do
  say 'rx2cpp: cannot find source:' input
  exit 66
end
source = charin(input, 1, chars(input))
call stream input, 'C', 'CLOSE'
compiler = .RxCompiler~new(source, existing)
generated = compiler~compile
/* Write only after full validation; a rejected input never overwrites output. */
status = stream(output, "C", "OPEN WRITE REPLACE")
if left(status, 6) \= "READY:" then do
  say "rx2cpp: cannot write:" output status
  exit 73
end
call charout output, generated
call stream output, "C", "CLOSE"
exit 0
compilerError:
  detail = condition('A')
  if detail \== '' & left(detail, 7) == 'rx2cpp:' then do
    say detail
    exit 65
  end
  say 'rx2cpp: internal compiler failure:' condition('O')~at('MESSAGE')
  exit 70
::requires 'core/RxCompiler.cls'
