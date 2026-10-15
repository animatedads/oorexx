/* Message instruction: receiver~selector(args) as a statement (RESULT is set, as in the interpreter).
   Only with interpreter objects available (host API); one shared message-send rule, no second parser. */
::class RxHybridMessageStatement public
::method accepts
  use arg ctx
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') = '' then return .false
  s = ctx~stream
  if (s~peek~kind == 'IDENT' | s~peek~kind == 'DOTIDENT') & wordpos(s~lookAheadOp(1), '~ ~~ [') > 0 then return .true
  /* Any other first term followed by a message (LanguageParser::nextInstruction: parseMessageTerm comes before
     keyword recognition): a function call f(...)~m, a literal 'abc'~m, a parenthesized (expr)~m. */
  n = self~termEnd(s)
  if n == 0 then return .false
  return wordpos(s~lookAheadOp(n), '~ ~~ [') > 0
/* The look-ahead offset just past the clause's first term when it is a function call, a literal or a parenthesized
   expression (0 otherwise). */
::method termEnd private
  use arg s
  kind = s~lookAheadKind(0)
  n = 0
  if kind == 'IDENT' | kind == 'STRING' | kind == 'NUMBER' | kind == 'INT' then do
    n = 1
    if s~lookAheadOp(1) \== '(' then do
      if kind == 'IDENT' then return 0      /* a plain symbol: the rule above */
      return n
    end
    first = s~lookAheadToken(0); paren = s~lookAheadToken(1)
    if \(paren~line == first~endLine & paren~col == first~endCol) then do
      if kind == 'IDENT' then return 0
      return n
    end
  end
  else if s~lookAheadOp(0) \== '(' then return 0
  /* skip the balanced parentheses starting at n */
  depth = 0
  do forever
    k = s~lookAheadKind(n)
    if k == 'EOF' | k == 'SEP' then return 0
    op = s~lookAheadOp(n)
    if op == '(' then depth += 1
    else if op == ')' then do
      depth -= 1
      if depth == 0 then return n + 1
    end
    n += 1
  end
::method emit
  use arg ctx
  s = ctx~stream
  if s~peek~text == 'SELF' & s~lookAheadText(3) == ':' then do
    /* SELF~selector:SUPER(...) statement: same send as the expression form, result discarded. */
    code = .RxHybridExprNoMessage~new~parse(ctx, .true)
    ctx~current~addInstruction('(void)' || code || ';')
    s~separator
    return
  end
  code = .RxExprMessage~new~parse(ctx, .true)
  ctx~current~addInstruction(code || ';')
  s~separator
::requires 'rules/ExprMessage.cls'
::requires 'hybrid/rules/HybridExprNoMessage.cls'
