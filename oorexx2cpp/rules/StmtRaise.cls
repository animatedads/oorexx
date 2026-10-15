/* RAISE, as LanguageParser::raiseNew parses it and RexxInstructionRaise / RexxActivation::raise run it:

     RAISE SYNTAX code | ERROR rc | FAILURE rc | USER name | HALT | LOSTDIGITS | NOMETHOD | NOSTRING | NOTREADY | NOVALUE
           [DESCRIPTION expr] [ADDITIONAL expr | ARRAY (expr, ...)] [RETURN [expr] | EXIT [expr]]
     RAISE PROPAGATE (in a trap handler)

   SYNTAX is raised in this activation (its traps apply). Any other condition ends the activation - with the RETURN /
   EXIT value as its result - and is raised in the caller, which traps it or ignores it (without RETURN it is an EXIT:
   an internal routine's ends the whole method or routine and is raised in its caller) (rx::RaiseToCaller; the native
   library lane hands it to the interpreter so the interpreted caller sees the condition). The code of SYNTAX, ERROR
   and FAILURE may be any expression (a literal 40.12, or (num)). */
::class RxStmtRaise public
::method accepts
  use arg ctx
  s = ctx~stream
  return s~is('RAISE') & wordpos(s~lookAheadOp(1), '= ~ ~~ [ :') = 0
::method emit
  use arg ctx, depth
  .local['RX2CPP.CLAUSEWORDS'] = 'ARRAY ADDITIONAL DESCRIPTION RETURN EXIT'   /* keywords of this clause end its expressions */
  s = ctx~stream
  s~expect('RAISE')
  /* RAISE PROPAGATE in a compiled trap handler: the trapped condition again, to the caller. */
  if s~accept('PROPAGATE') then do
    trapped = .false
    if ctx~current~hasMethod('TRAPPED') then trapped = ctx~current~trapped
    if \trapped then s~fail('RAISE PROPAGATE needs a SIGNAL ON trap in this method')
    ctx~line(depth, '_rxTrap.propagate();')
    s~separator
    return
  end
  if s~peek~kind \= 'IDENT' then s~fail('RAISE: a condition name is expected')
  condition = s~next~text
  conditions = 'SYNTAX ERROR FAILURE USER HALT LOSTDIGITS NOMETHOD NOSTRING NOTREADY NOVALUE'
  if wordpos(condition, conditions) = 0 then s~fail('RAISE: unknown condition ' || condition)
  rc = ''
  if wordpos(condition, 'SYNTAX ERROR FAILURE') > 0 then do
    t = s~peek
    if t~kind == 'NUMBER' | t~kind == 'INT' then do; s~next; rc = 'rx::Value::number(' || .RxQuote~cpp(t~text) || ')'; end
    else rc = ctx~logicalExpr~parse(ctx)
  end
  if condition == 'USER' then do
    if s~peek~kind \= 'IDENT' then s~fail('RAISE USER needs a condition name')
    condition = 'USER' s~next~text
  end
  description = ''; additional = ''; items = ''; isArray = .false; raiseResult = ''; hasResult = .false; returnForm = .false
  do while s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF'
    option = s~next~text
    select
      when option == 'DESCRIPTION' then description = ctx~logicalExpr~parse(ctx)
      when option == 'ADDITIONAL' then additional = ctx~logicalExpr~parse(ctx)
      when option == 'ARRAY' then do
        isArray = .true
        s~expect('(')
        do while \s~is(')')
          if s~is(',') then items = items || 'rx::Value::string(std::string()), '
          else items = items || ctx~logicalExpr~parse(ctx) || ', '
          if \s~accept(',') then leave
        end
        s~expect(')')
      end
      when option == 'RETURN' | option == 'EXIT' then do
        returnForm = option == 'RETURN'
        if s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF' then do
          hasResult = .true
          raiseResult = ctx~logicalExpr~parse(ctx)
        end
      end
      otherwise s~fail('RAISE: unexpected ' || option)
    end
  end
  s~separator
  arrayItems = items~strip('T', ' ')~strip('T', ',')
  if condition == 'SYNTAX' then do
    if isArray then args = 'std::vector<rx::Value>{' || arrayItems || '}'
    else if additional \== '' then args = 'rx::additionalItems(' || additional || ')'
    else args = 'std::vector<rx::Value>{}'
    ctx~line(depth, 'rx::raiseSyntaxCode(' || rc || ', ' || args || ', ' || word('true false', returnForm + 1) || ');')
    return
  end
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then s~fail('RAISE ' || condition || ' needs the native library lane')
  code = '{ rx::RaiseToCaller _rxRaise; _rxRaise.name = ' || .RxQuote~cpp(condition) || '; '
  if rc \== '' then code = code || '_rxRaise.rc = ' || rc || '; '
  if description \== '' then code = code || '_rxRaise.description = ' || description || '; '
  if isArray then code = code || '_rxRaise.additional = rx::messageValue(rx::nativeArrayClass(), "OF", std::vector<rx::Value>{' || arrayItems || '}, false); '
  else if additional \== '' then code = code || '_rxRaise.additional = ' || additional || '; '
  if hasResult then code = code || '_rxRaise.result = ' || raiseResult || '; '
  /* without RETURN the raise is an EXIT: from an internal routine it ends the method or routine (raiseExit) */
  if \returnForm then code = code || '_rxRaise.exitForm = true; '
  ctx~line(depth, code || 'throw _rxRaise; }')
::requires 'core/RxQuote.cls'
