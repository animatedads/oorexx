/* Native registers: whole-number arithmetic on simple variables as machine integers (the IBM REXX compiler's
   "dual-state" variables). Only in the native library lane (RxHybridCompiler sets RX2CPP.NATIVE), where each method
   body has its slot table _rxL (RxHybridMethod~useLocalSlots).

   While an expression is compiled, each piece that has a native form is recorded here against its generic C++ code:
     an integer literal (at most 9 digits, optional '-'):    INT64_C(n)               kind L (canonical text) or l
     a simple variable:                                      RX_NGET("V")             kind V
     + - * % // / of two native forms:                       rx::nAdd(_rxOk, a, b)    kind N
     unary - and +:                                          (-(a)) (a)               kind N
     = \= <> >< < <= > >= \< \> of two native forms:         (a < b) as 0 / 1         kind B
     & | && of two comparison results, \ of one:             (a & b) ...              kind B
   (strict comparisons and concatenation compare or join the characters: never native.)
   A native form is an int64 C++ expression that sets the local bool _rxOk false when an operand or a result is not a
   plain whole number of at most 9 digits (or a division is not exact, or by zero); the statement then runs its generic
   code instead, which gives the interpreter's result (a decimal, exponent notation, an error).
   Consumers: StmtAssign (V = expr: kinds N B L), conditions (kind B), StmtDo (control variable registers).
   The runtime side (minirexx_runtime.hpp nGet / nSet / nInv...) keeps every variable written as well as its register,
   and clears registers wherever something else may write a variable. */
::class RxNative public
::method tables class private
  expose forms kinds
  if var('FORMS') = 0 then do; forms = .directory~new; kinds = .directory~new; end
::method enabled class
  return .local['RX2CPP.NATIVE'] == 1 & value('RX2CPP_NO_NATIVE', , 'ENVIRONMENT') \== '1'
::method form class
  expose forms
  self~tables
  use arg code
  f = forms[code]
  if f == .nil then return ''
  return f
::method kind class
  expose kinds
  self~tables
  use arg code
  k = kinds[code]
  if k == .nil then return ''
  return k
::method record class private
  expose forms kinds
  self~tables
  use arg code, native, kind
  forms[code] = native
  kinds[code] = kind
  return code
-- a literal's text (NUMBER or STRING): whole numbers as NumCache integer reads them
::method literal class
  expose texts
  use arg text, code
  /* every literal's characters are kept (constant concatenation, OperatorRules~binary) */
  if var('TEXTS') = 0 then texts = .directory~new
  texts[code] = text
  if \self~enabled then return code
  digits = text
  if left(digits, 1) == '-' then digits = substr(digits, 2)
  if digits == '' | length(digits) > 9 | verify(digits, '0123456789') > 0 then return code
  n = text + 0
  kind = 'l'
  if n == text then kind = 'L'     /* the characters are the number's own (no leading zero, not -0) */
  return self~record(code, 'INT64_C(' || n || ')', kind)
-- the characters of a literal's code, or .nil
::method literalText class
  expose texts
  use arg code
  if var('TEXTS') = 0 then return .nil
  return texts[code]
::method variable class
  use arg name, code
  if \self~enabled | pos('.', name) > 0 | code~left(9) \== 'RX_VGET("' then return code
  return self~record(code, 'RX_NGET(' || .RxQuote~cpp(name) || ')', 'V')
::method binary class
  use arg lhs, selector, rhs, code
  if \self~enabled then return code
  a = self~form(lhs); b = self~form(rhs)
  if a == '' | b == '' then return code
  ka = self~kind(lhs); kb = self~kind(rhs)
  select
    when selector == '+' then return self~record(code, 'rx::nAdd(_rxOk, ' || a || ', ' || b || ')', 'N')
    when selector == '-' then return self~record(code, 'rx::nSub(_rxOk, ' || a || ', ' || b || ')', 'N')
    when selector == '*' then return self~record(code, 'rx::nMul(_rxOk, ' || a || ', ' || b || ')', 'N')
    when selector == '%' then return self~record(code, 'rx::nIntDiv(_rxOk, ' || a || ', ' || b || ')', 'N')
    when selector == '//' then return self~record(code, 'rx::nRem(_rxOk, ' || a || ', ' || b || ')', 'N')
    when selector == '/' then return self~record(code, 'rx::nDiv(_rxOk, ' || a || ', ' || b || ')', 'N')
    otherwise nop
  end
  op = ''
  select
    when selector == '=' then op = '=='
    when wordpos(selector, '\= <> ><') > 0 then op = '!='
    when selector == '<' then op = '<'
    when selector == '>' then op = '>'
    when wordpos(selector, '<= \>') > 0 then op = '<='
    when wordpos(selector, '>= \<') > 0 then op = '>='
    otherwise nop
  end
  if op \== '' then return self~record(code, 'static_cast<std::int64_t>((' || a || ') ' || op || ' (' || b || '))', 'B')
  /* & | && need operands exactly "0" or "1": only comparison results are known to be */
  if ka \== 'B' | kb \== 'B' then return code
  select
    when selector == '&' then return self~record(code, '((' || a || ') & (' || b || '))', 'B')
    when selector == '|' then return self~record(code, '((' || a || ') | (' || b || '))', 'B')
    when selector == '&&' then return self~record(code, '((' || a || ') ^ (' || b || '))', 'B')
    otherwise return code
  end
::method unary class
  use arg selector, operand, code
  if \self~enabled then return code
  a = self~form(operand)
  if a == '' then return code
  select
    when selector == '-' then return self~record(code, '(-(' || a || '))', 'N')
    when selector == '+' then return self~record(code, '(' || a || ')', 'N')
    when selector == '\' & self~kind(operand) == 'B' then return self~record(code, '(1 - (' || a || '))', 'B')
    otherwise return code
  end
-- code of a function call or message (may run any code, assign any variable): the registers are cleared after it
-- (not after a call marked pure: a built-in, which assigns no variable)
::method afterCall class
  expose pure
  use arg code
  if \self~enabled then return code
  if var('PURE') then if pure~hasIndex(code) then return code
  return 'RX_NAFTER(' || code || ')'
::method pureCall class
  expose pure
  use arg code
  if \self~enabled then return code
  if var('PURE') = 0 then pure = .set~new
  pure~put(code)
  return code
-- V = expr (simple V): the native statement, or '' when expr has no assignable native form
::method assignment class
  use arg name, expr, generic
  if \self~enabled | pos('.', name) > 0 then return ''
  f = self~form(expr)
  if f == '' | wordpos(self~kind(expr), 'N B L V') == 0 then return ''
  /* V = Y: the number written only when Y's characters are its number's own (RX_NCANON); else Y's value copied */
  if self~kind(expr) == 'V' then f = f~changeStr('RX_NGET(', 'RX_NCANON(')
  v = .RxQuote~cpp(name)
  return '{ bool _rxOk = _rxNOn && rx::nOn(vars.numeric); std::int64_t _rxR = 0; if (_rxOk) _rxR = ' || f || -
         '; if (_rxOk) RX_NSET(' || v || ', _rxR); else { ' || generic self~afterAssign(name, expr) '} }'
-- after the generic V = expr: V's register is the variable's own when expr is a simple variable, else cleared
::method afterAssign class
  use arg name, expr
  if \self~enabled | pos('.', name) > 0 then return ''
  if self~kind(expr) == 'V' then
    return 'RX_NCOPY(' || .RxQuote~cpp(name) || ', ' || self~form(expr)~changeStr('RX_NGET(', 'RX_NFROM(') || ');'
  return self~invalidate(name)
-- after a generic write of simple variable V
::method invalidate class
  use arg name
  if \self~enabled | pos('.', name) > 0 then return ''
  return 'RX_NINV(' || .RxQuote~cpp(name) || ');'
::method invalidateAll class
  if \self~enabled then return ''
  return 'RX_NINV_ALL;'
-- the register of V set to the C++ int64 n (its variable already written)
::method put class
  use arg name, n
  if \self~enabled | pos('.', name) > 0 then return ''
  return 'RX_NPUT(' || .RxQuote~cpp(name) || ', ' || n || ');'
-- C++ bool: V's register holds the C++ int64 n ('' when not native)
::method holds class
  use arg name, n
  if \self~enabled | pos('.', name) > 0 then return ''
  return 'RX_NHOLDS(' || .RxQuote~cpp(name) || ', ' || n || ')'
-- V's register and variable set to the C++ int64 n
::method set class
  use arg name, n
  if \self~enabled | pos('.', name) > 0 then return ''
  return 'RX_NSET(' || .RxQuote~cpp(name) || ', ' || n || ');'
-- a condition (C++ bool) for code: native when code is a comparison result, else generic (the C++ bool given)
::method condition class
  use arg code, generic
  if \self~enabled | self~kind(code) \== 'B' then return generic
  return '([&]() -> bool { bool _rxOk = _rxNOn && rx::nOn(vars.numeric); if (_rxOk) { const bool _rxB = (' || self~form(code) || -
         ') != 0; if (_rxOk) return _rxB; } return ' || generic || '; }())'
::requires 'core/RxQuote.cls'
