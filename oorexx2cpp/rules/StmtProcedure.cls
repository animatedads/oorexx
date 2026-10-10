/* Guard: PROCEDURE must precede all statements of its routine. */
::class RxStmtProcedure public
::method accepts
  use arg ctx
  return ctx~stream~is('PROCEDURE')
::method emit
  use arg ctx, depth
  ctx~stream~fail('PROCEDURE must be the first instruction in an internal routine')
