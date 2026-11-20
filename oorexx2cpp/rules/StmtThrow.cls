/* THROW (RFE #31, trunk r13547+), as LanguageParser::raiseNew(true) parses it and RexxInstructionRaise::throwCondition
   runs it:

     THROW SYNTAX code | ERROR rc | FAILURE rc | USER name | HALT | LOSTDIGITS | NOMETHOD | NOSTRING | NOTREADY | NOVALUE
           [DESCRIPTION expr] [ADDITIONAL expr | ARRAY (expr, ...)]
     THROW PROPAGATE [DESCRIPTION expr] [ADDITIONAL expr | ARRAY (expr, ...)]

   The condition is raised in this activation (its CATCH clauses and SIGNAL ON traps; CALL ON never takes it) and,
   if nothing takes it, in its caller, and so on, as a SYNTAX error goes: no RETURN or EXIT (25.941). THROW SYNTAX is
   RAISE SYNTAX, with THROWN .true. THROW PROPAGATE throws the condition being handled (98.918 without one). THROW is
   not a reserved word: THROW = ..., THROW += ... are assignments. The activation has traps (RxStream
   methodBodySignals): the condition knows the activation that threw it (PROPAGATED). Native library lane only. */
::class RxStmtThrow public
::method accepts
  use arg ctx
  s = ctx~stream
  if \s~is('THROW') then return .false
  if wordpos(s~lookAheadOp(1), '= ~ ~~ [ :') > 0 then return .false
  return \.RxCompoundAssignmentOps~isSupported(s~lookAheadText(1))
::method emit
  use arg ctx, depth
  .local['RX2CPP.CLAUSEWORDS'] = 'ARRAY ADDITIONAL DESCRIPTION RETURN EXIT'   /* keywords of this clause end its expressions */
  s = ctx~stream
  s~expect('THROW')
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then s~fail('THROW needs the native library lane')
  propagate = s~accept('PROPAGATE')
  condition = ''; rc = ''
  if \propagate then do
    if s~peek~kind \= 'IDENT' then s~fail('Error 20.937: Symbol expected after THROW keyword')
    condition = s~next~text
    conditions = 'SYNTAX ERROR FAILURE USER HALT LOSTDIGITS NOMETHOD NOSTRING NOTREADY NOVALUE'
    if wordpos(condition, conditions) = 0 then s~fail('Error 25.940: THROW must be followed by one of the keywords' conditions 'PROPAGATE; found "'condition'"')
    if wordpos(condition, 'SYNTAX ERROR FAILURE') > 0 then do
      t = s~peek
      if t~kind == 'NUMBER' | t~kind == 'INT' then do; s~next; rc = 'rx::Value::number(' || .RxQuote~cpp(t~text) || ')'; end
      else rc = ctx~logicalExpr~parse(ctx)
    end
    if condition == 'USER' then do
      if s~peek~kind \= 'IDENT' then s~fail('Error 20.904: Symbol expected after USER keyword')
      condition = 'USER' s~next~text
    end
  end
  description = ''; additional = ''; items = ''; isArray = .false
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
      otherwise s~fail('Error 25.941: THROW must be followed by one of the keywords ADDITIONAL, ARRAY, DESCRIPTION; found "'option'"')
    end
  end
  s~separator
  arrayItems = items~strip('T', ' ')~strip('T', ',')
  if isArray then additional = 'rx::messageValue(rx::nativeArrayClass(), "OF", std::vector<rx::Value>{' || arrayItems || '}, false)'
  opt = 'std::optional<rx::Value>()'
  d = opt; if description \== '' then d = 'std::optional<rx::Value>(' || description || ')'
  a = opt; if additional \== '' then a = 'std::optional<rx::Value>(' || additional || ')'
  if propagate then do
    ctx~line(depth, '_rxTrap.throwPropagate(' || d || ', ' || a || ');')
    return
  end
  r = opt; if rc \== '' then r = 'std::optional<rx::Value>(' || rc || ')'
  ctx~line(depth, 'rx::throwCondition(' || .RxQuote~cpp(condition) || ', ' || r || ', ' || d || ', ' || a || ', &_rxTrap, _rxLine);')
::requires 'core/RxQuote.cls'
::requires 'rules/CompoundAssignmentOps.cls'
