/* REPLY [expr], as RexxInstructionReply / RexxActivation::reply run it: the method's caller gets the value (bare REPLY:
   no result) and continues while the method runs on. Native library lane: the method runs on its own activity from
   the start (its declaration stub starts it and waits for the reply, rx::ReplyScope), so REPLY hands the value to the
   waiting stub (rx::replyInstruction). Errors: a second REPLY 98.935; REPLY in a routine or an internal routine
   99.919 (not an object method invocation); after a REPLY, RETURN / EXIT with a value 98.936 / 98.937 (rx::afterReply,
   emitted by RETURN and EXIT in a method that replies). */
::class RxHybridReply public
::method accepts
  use arg ctx
  s = ctx~stream
  return s~is('REPLY') & wordpos(s~lookAheadOp(1), '= ~ ~~ [ : += -= *= /= %= //= ||= &= |= &&= **=') = 0
::method emit
  use arg ctx
  s = ctx~stream
  s~expect('REPLY')
  bare = s~peek~kind == 'SEP' | s~peek~kind == 'EOF'
  if \bare then value = ctx~logicalExpr~parse(ctx)
  s~separator
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then s~fail('REPLY needs the native library lane')
  /* a ::ROUTINE is no object method invocation (raised when the clause runs, as interpreted) */
  if ctx~className == 'RX2CPP_ROUTINE_IMPL' then do
    ctx~current~addRaw('rx::raiseSyntaxCode(rx::Value::number("99.919"), std::vector<rx::Value>{});')
    return
  end
  internal = 'false'
  if ctx~current~hasInternalCalls then internal = '_rxInternal'
  if bare then ctx~current~addRaw('rx::replyInstruction(std::nullopt, ' || internal || ');')
  else ctx~current~addRaw('rx::replyInstruction(std::optional<rx::Value>(' || value || '), ' || internal || ');')
