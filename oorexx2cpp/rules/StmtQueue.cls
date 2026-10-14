/* PUSH [expr] / QUEUE [expr]: a line onto the interpreter's current external data queue (PUSH: LIFO, QUEUE: FIFO; no
   expression: an empty line). The queue belongs to the interpreter, so this needs the native library lane. */
::class RxStmtQueue public
::method accepts
  use arg ctx
  s = ctx~stream
  return (s~is('PUSH') | s~is('QUEUE')) & s~lookAheadText(1) \== '='
::method emit
  use arg ctx, depth
  s = ctx~stream
  lifo = s~is('PUSH')
  s~next
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then s~fail('PUSH / QUEUE need the native library lane (the interpreter owns the queue)')
  expr = 'rx::Value::string(std::string())'
  if s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF' then expr = ctx~logicalExpr~parse(ctx)
  ctx~line(depth, 'rx::interpreterQueue(' || word('false true', lifo + 1) || ', ' || expr || ');')
  s~separator
