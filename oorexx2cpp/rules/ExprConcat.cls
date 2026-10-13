/* Explicit concatenation (||), associating left-to-right. In Rexx precedence it binds
   looser than + and - and tighter than comparison. This object sits in the addExpr slot
   so every consumer of that slot (comparison, DO control expressions) gets the correct
   level; it delegates to the additive rule for its operands. Blank concatenation and
   abuttal are implemented here (selectors ' ' and '||'). */
::class RxExprConcat public
::method init
  expose inner
  inner = .RxExprAdd~new
::method parse
  expose inner
  use arg ctx
  s = ctx~stream
  value = inner~parse(ctx)
  do forever
    if s~is('||') then do
      selector = s~next~text
      rhs = inner~parse(ctx)
      value = .RxOperatorRules~binary(value, selector, rhs)
    end
    else if self~startsTerm(s) then do
      /* Blank concatenation (one space joined in) or abuttal (adjacent terms, no space). */
      prev = s~previous
      if s~peek~line == prev~endLine & s~peek~col == prev~endCol then selector = '||'
      else selector = ' '
      rhs = inner~parse(ctx)
      value = .RxOperatorRules~binary(value, selector, rhs)
    end
    else leave
  end
  return value
/* True when the next token begins a term (so two terms in a row concatenate). Clause keywords never do. */
::method startsTerm
  use arg s
  t = s~peek
  select
    when t~kind == 'STRING' | t~kind == 'NUMBER' | t~kind == 'INT' | t~kind == 'DOTIDENT' then return .true
    when t~kind == 'IDENT' then do
      /* Clause keywords end a term: the structural ones always, others only inside the clause that has them (a DO
         header's TO/BY/FOR/WHILE/UNTIL/OVER, PARSE VALUE's WITH, RAISE's options); elsewhere they are variables. */
      clauseWords = .local['RX2CPP.CLAUSEWORDS']
      if clauseWords == .nil then clauseWords = ''
      if wordpos(t~text, 'THEN ELSE END DO WHEN OTHERWISE IF' clauseWords) = 0 then return .true
      /* A sub-keyword abutted to the previous term ('x['name) is a symbol in abuttal, not a keyword. */
      prev = s~previous
      return t~line == prev~endLine & t~col == prev~endCol
    end
    when t~kind == 'OP' & t~text == '(' then return .true
    otherwise return .false
  end
::requires 'rules/ExprAdd.cls'
::requires 'rules/OperatorRules.cls'
