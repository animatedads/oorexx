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
attempt = 1
existing = stream(input, "C", "QUERY EXISTS")
if existing == "" then do
  say 'rx2cpp: cannot find source:' input
  exit 66
end
source = charin(input, 1, chars(input))
call stream input, 'C', 'CLOSE'
/* .ROUTINES must report the defining package's actual ::ROUTINEs.
   Host the directive section as a unit before compiling main code, rather than
   building a false empty native routine directory. Lexer inspection ignores
   quoted strings and comments. RX2CPP_HOSTED=0 retains fail-closed behavior. */
signal on syntax name compilerError
signal on error name compilerError
signal on failure name compilerError
if value('RX2CPP_HOSTED', , 'ENVIRONMENT') \= '0' then do
  directiveLine = .RxHostSplit~firstDirectiveLine(source)
  if directiveLine > 0 then do
    candidateParts = .RxHostSplit~split(source, directiveLine)
    symbolTokens = .RxLexer~new(candidateParts[1])~scan
    do symbolToken over symbolTokens
      if symbolToken~kind == 'DOTIDENT' & symbolToken~text == 'ROUTINES' then do
        mainPart = candidateParts[1]
        unitPart = candidateParts[2]
        attempt = 2
        leave
      end
    end
  end
end
compileAttempt:
signal on syntax name compilerError
signal on error name compilerError
signal on failure name compilerError
if attempt == 1 then compiler = .RxCompiler~new(source, existing)
else compiler = .RxCompiler~new(mainPart, existing, unitPart)
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
  /* Hosted tier: a rejection inside the directive section (::CLASS options, ::REQUIRES of Rexx programs, ...)
     retries with that section run by the embedded interpreter; a rejection in the main code stays final. */
  if attempt == 1 & value('RX2CPP_HOSTED', , 'ENVIRONMENT') \= '0' & left(detail, 7) == 'rx2cpp:' then do
    parse var detail 'rx2cpp:' failLine ':' .
    firstLine = .RxHostSplit~firstDirectiveLine(source)
    if datatype(failLine, 'W') & firstLine > 0 then do
      if failLine >= firstLine then do
        parts = .RxHostSplit~split(source, firstLine)
        mainPart = parts[1]
        unitPart = parts[2]
        attempt = 2
        signal compileAttempt
      end
    end
  end
  if detail \== '' & left(detail, 7) == 'rx2cpp:' then do
    say detail
    exit 65
  end
  say 'rx2cpp: internal compiler failure:' condition('O')~at('MESSAGE')
  exit 70
::requires 'core/RxCompiler.cls'
