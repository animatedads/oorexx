/* Compile an ooRexx ::class to native ooRexx-loadable package source.
   The ooRexx-written precompiler owns parsing and C++ emission. */
parse arg input output libraryName
if input == '' | output == '' | libraryName == '' then do
  say 'Usage: rexx rx2cpp_native.rex source.cls output.cpp library_name'
  exit 64
end
signal on syntax name compilerError
signal on error name compilerError
signal on failure name compilerError
if stream(input, 'C', 'QUERY EXISTS') == '' then do
  say 'rx2cpp: missing class source:' input
  exit 66
end
source = charin(input, 1, chars(input))
call stream input, 'C', 'CLOSE'
unit = .RxHybridCompiler~new(source)~parse
do m over unit~methods
  if m~declaration \== '' | m~isAbstract then raise syntax 40.1 array('rx2cpp: method options (GUARDED/UNGUARDED/PRIVATE/PROTECTED/ABSTRACT) require the native package compiler')
end
if unit~classMethods~items > 0 then raise syntax 40.1 array('rx2cpp: CLASS methods require the native package compiler')
cpp = .RxNativePackageEmitter~new~emit(unit, libraryName)
state = stream(output, 'C', 'OPEN WRITE REPLACE')
if left(state, 6) \= 'READY:' then raise syntax 40.1 array('rx2cpp: cannot write ' || output)
call charout output, cpp
call stream output, 'C', 'CLOSE'
say 'rx2cpp native package compiled' unit~className 'methods='unit~methods~items 'library='libraryName
exit 0
compilerError:
  detail = condition('A')
  if detail \== '' & left(detail, 7) == 'rx2cpp:' then do
    say detail
    exit 65
  end
  say 'rx2cpp: native package compiler failure:' condition('O')~at('MESSAGE')
  exit 70
::requires 'hybrid/compiler/RxHybridCompiler.cls'
::requires 'hybrid/compiler/RxNativePackageEmitter.cls'
