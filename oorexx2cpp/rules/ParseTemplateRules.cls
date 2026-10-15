/* A PARSE template, as LanguageParser::parseNew builds it: a list of triggers, each a pattern with the variables
   written before it (the last trigger, the template's end, has no pattern). Patterns:
     'string' | (expr)                    search (CASELESS: caseless search)
     n | =n | =(expr)                     absolute position
     +n | +(expr)   -n | -(expr)          relative position (- : the backward rule)
     >n | >(expr)   <n | <(expr)          length positions
   A variable is a symbol, a message term (d~name, a[i]) or the placeholder '.'.
   parse answers an array of triggers; each trigger is an array: the C++ movement call on the cursor _pc (or '' for
   the end), then the targets. emit writes the C++ that runs them in order, so a pattern's expression is evaluated
   when its trigger runs (after the variables before it are assigned), as interpreted (RexxTarget, ParseTrigger). */
::class RxParseTemplateRules public
::method parse class
  use arg ctx, commaDelimited
  if arg(2, O) then commaDelimited = .false
  s = ctx~stream
  triggers = .array~new
  current = .array~new                  /* the targets waiting for the next pattern */
  do while s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF' & \s~is(',')
    t = s~peek
    move = ''
    select
      when t~kind == 'IDENT' & .RxMessageTarget~isTarget(ctx) then current~append(.RxMessageTarget~parse(ctx))
      when t~kind == 'IDENT' then current~append('VAR:' || s~next~text)
      when s~accept('.') then current~append('.')
      when t~kind == 'INT' | t~kind == 'NUMBER' then move = 'absolute(' || self~constantPosition(s~next~text) || ')'
      when t~kind == 'OP' & wordpos(t~text, '= + - < >') > 0 then do
        op = s~next~text
        select
          when op == '=' then call = 'absolute'
          when op == '+' then call = 'forward'
          when op == '-' then call = 'backward'
          when op == '>' then call = 'forwardLength'
          otherwise call = 'backwardLength'
        end
        if s~accept('(') then do
          expr = ctx~logicalExpr~parse(ctx)
          s~expect(')')
          move = call || '(rx::ParseCursor::position(' || expr || ', vars.numeric))'
        end
        else if s~peek~kind == 'INT' | s~peek~kind == 'NUMBER' then move = call || '(' || self~constantPosition(s~next~text) || ')'
        else if s~peek~kind == 'SEP' | s~peek~kind == 'EOF' then s~fail('PARSE: a position is expected after' op)
        else s~fail('PARSE: a position (a number or an expression in parentheses) is expected after' op)
      end
      when t~kind == 'STRING' then move = 'search(rx::Value::string(' || .RxQuote~cpp(s~next~text) || '))'
      when s~accept('(') then do
        expr = ctx~logicalExpr~parse(ctx)
        s~expect(')')
        move = 'search(' || expr || ')'
      end
      otherwise s~fail('unsupported PARSE template component')
    end
    if move \== '' then do
      trigger = .array~of(move)
      do target over current; trigger~append(target); end
      triggers~append(trigger)
      current = .array~new
    end
  end
  trigger = .array~of('')
  do target over current; trigger~append(target); end
  triggers~append(trigger)
  return triggers
/* A constant symbol position: a whole number of digits is used as is; any other (1e1, 3.0) is converted when it runs. */
::method constantPosition class private
  use arg text
  if verify(text, '0123456789') == 0 & text~length <= 18 then return text
  return 'rx::ParseCursor::position(rx::Value::number(' || .RxQuote~cpp(text) || '), vars.numeric)'
/* The C++ of one template's triggers on the cursor _pc. */
::method emit class
  use arg ctx, depth, triggers
  do trigger over triggers
    count = trigger~items - 1
    if trigger[1] == '' then do
      if count == 0 then iterate      /* the end with no variables: nothing to do */
      ctx~line(depth, '_pc.toEnd();')
    end
    else ctx~line(depth, '_pc.' || trigger[1] || ';')
    do i = 1 to count
      target = trigger[i + 1]
      last = i == count
      if target == '.' then do
        if last then ctx~line(depth, '_pc.skipRest();')
        else ctx~line(depth, '_pc.skipWord();')
        iterate
      end
      if last then piece = '_pc.rest()'
      else piece = '_pc.word()'
      if target~left(4) == 'VAR:' then ctx~line(depth, .RxCompoundSymbols~store(target~substr(5), piece))
      else ctx~line(depth, target~changeStr('RX2CPP_TARGET_VALUE', piece))
    end
  end
::requires 'rules/CompoundSymbols.cls'
::requires 'rules/MessageTarget.cls'
::requires 'core/RxQuote.cls'
