/* Operator compilation ruleset.
   ooRexx infix operators are method sends to the left operand.
   Keep the exact ooRexx message selector -- particularly \=, NOT \\=.
   A future target emitter can implement sendBinary/sendUnary differently without
   modifying the grammar classes; no source string is ever evaluated as code. */
::class RxOperatorRules public
::method binary class
  use arg lhs, selector, rhs
  if wordpos(selector, '+ - * / % // ** | || & && = \= <> >< == \== < <= > >=') == 0 then do
    raise syntax 40.1 array ('rx2cpp: unsupported binary operator ' || selector)
  end
  /* Native C++ does not guarantee function-argument evaluation order.
     The receiver must be evaluated before the right operand, even when
     either side contains an arbitrarily chained method expression. */
  return '([&]() -> rx::Value { rx::Value _left = ' || lhs || '; ' || -
         'rx::Value _right = ' || rhs || '; return rx::sendBinary(_left, ' || -
         .RxQuote~cpp(selector) || ', _right, vars.numeric); }())'
::method unary class
  use arg selector, operand
  if wordpos(selector, '+ - \') == 0 then do
    raise syntax 40.1 array ('rx2cpp: unsupported unary operator ' || selector)
  end
  return 'rx::sendUnary(' || .RxQuote~cpp(selector) || ', ' || operand || ', vars.numeric)'
::requires 'core/RxQuote.cls'
