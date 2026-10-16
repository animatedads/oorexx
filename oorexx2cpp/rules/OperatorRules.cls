/* Operator compilation ruleset.
   ooRexx infix operators are method sends to the left operand.
   Keep the exact ooRexx message selector -- particularly \=, NOT \\=.
   A future target emitter can implement sendBinary/sendUnary differently without
   modifying the grammar classes; no source string is ever evaluated as code. */
::class RxOperatorRules public
::method binary class
  use arg lhs, selector, rhs
  if selector \== ' ' & wordpos(selector, '+ - * / % // ** | || & && = \= <> >< == \== < <= > >= << >> <<= >>= \< \> \<< \>>') == 0 then do
    raise syntax 40.1 array ('rx2cpp: unsupported binary operator ' || selector)
  end
  /* Native C++ does not guarantee function-argument evaluation order.
     The receiver must be evaluated before the right operand, even when
     either side contains an arbitrarily chained method expression. */
  /* Operands that cannot run Rexx code (a plain variable, a literal) are read in place instead of copied: a literal is
     a constant, and a variable is read where it is kept when nothing is evaluated between reading it and the operator
     (its numeric form, once known, then stays with the variable's value). A variable holding an object is still
     copied: the operator's method could change the variable. */
  if self~plainVariable(lhs) & (self~plainVariable(rhs) | self~literal(rhs)) then left = self~bindVariable('_left', lhs)
  else if self~literal(lhs) then left = 'const rx::Value &_left = ' || lhs || '; '
  else left = 'rx::Value _left = ' || lhs || '; '
  if self~literal(rhs) then right = 'const rx::Value &_right = ' || rhs || '; '
  else if self~plainVariable(rhs) then right = self~bindVariable('_right', rhs)
  else right = 'rx::Value _right = ' || rhs || '; '
  return '([&]() -> rx::Value { ' || left || right || 'return rx::sendBinary(_left, ' || -
         .RxQuote~cpp(selector) || ', _right, vars.numeric); }())'
-- RX_VGET("NAME") and nothing else
::method plainVariable class private
  use arg code
  return code~left(9) == 'RX_VGET("' & code~right(2) == '")' & pos('(', code, 9) == 0 & pos(')', code) == length(code)
-- a static literal (ExprAtom)
::method literal class private
  use arg code
  return abbrev(code, '([]() -> const rx::Value & { static const rx::Value _rxLit')
-- name = the variable's value in place, or a copy when it holds an object
::method bindVariable class private
  use arg name, code
  ref = 'RX_VREF(' || code~substr(9)
  return 'const rx::Value &' || name || 'R = ' || ref || '; std::optional<rx::Value> ' || name || 'K; if (' || name || 'R.isObject()) ' || -
         name || 'K.emplace(' || name || 'R); const rx::Value &' || name || ' = ' || name || 'K ? *' || name || 'K : ' || name || 'R; '
::method unary class
  use arg selector, operand
  if wordpos(selector, '+ - \') == 0 then do
    raise syntax 40.1 array ('rx2cpp: unsupported unary operator ' || selector)
  end
  return 'rx::sendUnary(' || .RxQuote~cpp(selector) || ', ' || operand || ', vars.numeric)'
::requires 'core/RxQuote.cls'
