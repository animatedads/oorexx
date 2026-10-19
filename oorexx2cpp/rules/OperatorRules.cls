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
  /* Two literals joined (||, abuttal, blank): the String class's concatenation of two constant strings is a constant,
     made once as one literal ('with' 2 'args', 1234"5678"). */
  if selector == '||' | selector == ' ' then do
    lt = .RxNative~literalText(lhs)
    rt = .RxNative~literalText(rhs)
    if lt \== .nil & rt \== .nil then do
      text = lt || rt
      if selector == ' ' then text = lt || ' ' || rt   /* exactly one blank between them */
      return .RxNative~literal(text, '([]() -> const rx::Value & { static const rx::Value _rxLit = rx::Value::string(' || -
             .RxQuote~cpp(text) || '); return _rxLit; }())')
    end
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
  /* The selector is known here: arithmetic and comparisons call their own entry (two plain whole numbers are worked as
     machine integers there; any other operands get the same message sendBinary sends). */
  entryCall = self~entry(selector)
  if entryCall \== '' then
    code = '([&]() -> rx::Value { ' || left || right || 'return ' || entryCall || ', _right, vars.numeric); }())'
  else code = '([&]() -> rx::Value { ' || left || right || 'return rx::sendBinary(_left, ' || -
              .RxQuote~cpp(selector) || ', _right, vars.numeric); }())'
  return .RxNative~binary(lhs, selector, rhs, code)
-- the C++ call (up to the right operand) for a selector with its own entry, else ''
::method entry class private
  use arg selector
  select
    when selector == '+' then return 'rx::opAdd(_left'
    when selector == '-' then return 'rx::opSub(_left'
    when selector == '*' then return 'rx::opMul(_left'
    when selector == '/' then return 'rx::opDiv(_left'
    when selector == '%' then return 'rx::opIntDiv(_left'
    when selector == '//' then return 'rx::opRem(_left'
    otherwise nop
  end
  op = self~cmpOp(selector)
  if op == '' then return ''
  return 'rx::opCmp(_left, rx::CmpOp::' || op || ', ' || .RxQuote~cpp(selector)
-- rx::CmpOp of a comparison selector (rx_rexx_number.hpp cmpOpOf), else ''
::method cmpOp class
  use arg selector
  select
    when selector == '=' then return 'Eq'
    when selector == '<' then return 'Lt'
    when selector == '>' then return 'Gt'
    when selector == '==' then return 'StrictEq'
    when wordpos(selector, '\= <> ><') > 0 then return 'Ne'
    when wordpos(selector, '<= \>') > 0 then return 'Le'
    when wordpos(selector, '>= \<') > 0 then return 'Ge'
    when selector == '<<' then return 'SLt'
    when selector == '>>' then return 'SGt'
    when selector == '\==' then return 'StrictNe'
    when wordpos(selector, '<<= \>>') > 0 then return 'SLe'
    when wordpos(selector, '>>= \<<') > 0 then return 'SGe'
    otherwise return ''
  end
/* The C++ bool of an IF / WHEN / WHILE / UNTIL / list condition (truth: its rx::Truth). A condition that is one
   comparison (binary above) is tested without making its "1" / "0" value: rx::cmpTest. */
::method condition class
  use arg code, truth
  return .RxNative~condition(code, self~genericCondition(code, truth))
::method genericCondition class private
  use arg code, truth
  /* S.tail as the whole condition: tested in place (rx::stemCondition1), no copy of the element */
  if abbrev(code, 'rx::stemGet1(') & code~right(1) == ')' then do
    depth = 0
    do k = length('rx::stemGet1(') to length(code)
      c = code~substr(k, 1)
      if c == '(' then depth += 1
      else if c == ')' then do
        depth -= 1
        if depth == 0 then leave
      end
    end
    if k == length(code) then return 'rx::stemCondition1(' || code~substr(14, length(code) - 14) || ', ' || truth || ')'
  end
  head = '([&]() -> rx::Value { '
  tail = ', vars.numeric); }())'
  marker = 'return rx::opCmp(_left, '
  p = code~lastPos(marker)
  if p > 0 & abbrev(code, head) & code~right(tail~length) == tail then do
    rest = code~substr(p + marker~length)
    if pos('return ', rest) == 0 then
      return '([&]() -> bool { ' || code~substr(head~length + 1, p - head~length - 1) || 'return rx::cmpTest(_left, ' || -
             rest~left(rest~length - tail~length) || ', vars.numeric, ' || truth || '); }())'
  end
  return 'rx::condition(' || code || ', ' || truth || ')'
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
  return .RxNative~unary(selector, operand, 'rx::sendUnary(' || .RxQuote~cpp(selector) || ', ' || operand || ', vars.numeric)')
::requires 'core/RxQuote.cls'
::requires 'rules/RxNative.cls'
