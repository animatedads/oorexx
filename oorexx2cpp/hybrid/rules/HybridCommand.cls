/* A clause that is only an expression is a command: its value goes to the current ADDRESS environment, run by the
   interpreter that loaded the library (RC set), as interpreted. Only clauses no other rule claims reach here: a literal
   string, a number, a parenthesized expression or a function call first (NAME(...) abutted). */
::class RxHybridCommand public
::method accepts
  use arg ctx
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then return .false
  s = ctx~stream
  t = s~peek
  if t~kind == 'STRING' | t~kind == 'NUMBER' | t~kind == 'INT' then return s~lookAheadText(1) \== '='
  if t~kind == 'OP' & t~text == '(' then return .true
  if t~kind == 'IDENT' & s~lookAheadText(1) == '(' then do
    p = s~lookAheadToken(1)
    if p~line == t~endLine & p~col == t~endCol then return .true
  end
  /* A symbol that is not an instruction keyword, not assigned (=, op=, [..]=), not a label and not a message receiver:
     the clause is an expression (setWriteOnly fileName), so a command. */
  if t~kind == 'IDENT' then do
    keywords = 'ADDRESS ARG CALL DO DROP ELSE END EXIT EXPOSE FORWARD GUARD IF INTERPRET ITERATE LEAVE LOOP NOP NUMERIC' -
               'OPTIONS OTHERWISE PARSE PROCEDURE PULL PUSH QUEUE RAISE REPLY RETURN SAY SELECT SIGNAL THEN TRACE USE WHEN'
    if wordpos(t~text, keywords) > 0 then return .false
    if s~lookAheadKind(1) == 'STRING' then return .true
    next = s~lookAheadText(1)
    if wordpos(next, '= [ : ~ ~~ .') > 0 then return .false
    if .RxCompoundAssignmentOps~isSupported(next) then return .false
    return .true
  end
  return .false
::method emit
  use arg ctx
  s = ctx~stream
  command = ctx~logicalExpr~parse(ctx)
  ctx~current~addRaw('rx::interpreterCommand(vars, rx::Value::string(rx::addressEnvironment()), ' || command || ');')
  s~separator
::requires 'rules/CompoundAssignmentOps.cls'
