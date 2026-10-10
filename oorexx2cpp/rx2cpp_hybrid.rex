/* Hybrid class compiler entry point, implemented wholly in ooRexx.
   Strict subset compiled to a C++17 class + a generated ooRexx proxy. */
parse arg input prefix
if input == '' | prefix == '' then do
  say 'Usage: rexx rx2cpp_hybrid.rex class.rex output-prefix'
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
  if m~guard \== '' then raise syntax 40.1 array('rx2cpp: GUARDED/UNGUARDED requires the native package compiler')
end
cpp = .RxHybridCppEmitter~new~emit(unit)
proxy = .RxHybridProxyEmitter~new~emit(unit)
header = '#ifndef RX2CPP_GENERATED_HPP' || '0a'x || ,
         '#define RX2CPP_GENERATED_HPP' || '0a'x || ,
         '#include "compiled_registry.hpp"' || '0a'x || ,
         '#include <memory>' || '0a'x || ,
         'namespace rx2cpp {' || '0a'x || ,
         'std::shared_ptr<CompiledObject> makeGeneratedObject();' || '0a'x || ,
         '}' || '0a'x || '#endif' || '0a'x
call writeOutput prefix || '.hpp', header
call writeOutput prefix || '.cpp', cpp
call writeOutput prefix || '_proxy.rex', proxy
say 'rx2cpp hybrid compiled' unit~className 'methods='unit~methods~items
exit 0
writeOutput:
  use arg filename, contents
  state = stream(filename, 'C', 'OPEN WRITE REPLACE')
  if left(state, 6) \= 'READY:' then raise syntax 40.1 array('rx2cpp: cannot write ' || filename)
  call charout filename, contents
  call stream filename, 'C', 'CLOSE'
  return
compilerError:
  detail = condition('A')
  if detail \== '' & left(detail, 7) == 'rx2cpp:' then do
    say detail
    exit 65
  end
  say 'rx2cpp: internal compiler failure:' condition('O')~at('MESSAGE')
  exit 70
::requires 'hybrid/compiler/RxHybridCompiler.cls'
::requires 'hybrid/compiler/RxHybridCppEmitter.cls'
::requires 'hybrid/compiler/RxHybridProxyEmitter.cls'
