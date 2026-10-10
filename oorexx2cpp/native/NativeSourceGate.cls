/* Native ABI source preflight. Use the real Rexx lexer so comments and
   string literals never masquerade as directives. Unsupported package
   features are rejected before emitting any C++ source or executable. */
::class RxNativeSourceGate public
::method validate
  use arg source
  tokens = .RxLexer~new(source)~scan
  previous = 'SEP'
  do i = 1 to tokens~items
    token = tokens[i]
    if token~kind == 'EOF' then leave
    if token~text == '::' & previous == 'SEP' then do
      if i == tokens~items then self~reject(token~line, 'incomplete directive')
      directive = tokens[i+1]~text
      select
        when directive == 'CLASS' then nop
        when directive == 'METHOD' then nop
        when directive == 'ATTRIBUTE' then nop
        when directive == 'CONSTANT' then nop
        when directive == 'OPTIONS' then nop /* validated by RxNativePackageOptions */
        when directive == 'ROUTINE' then self~reject(token~line, 'package routines not implemented')
        when directive == 'REQUIRES' then self~reject(token~line, 'package dependencies not implemented')
        otherwise self~reject(token~line, 'unsupported native directive ' || directive)
      end
    end
    if token~kind == 'SEP' then previous = 'SEP'
    else previous = 'OTHER'
  end
  return .true
::method reject private
  use arg lineNo, reason
  raise syntax 40.1 array('rx2cpp: native preflight line ' || lineNo || ': ' || reason)
::requires 'core/RxLexer.cls'
