/* PROCEDURE [EXPOSE names] as the first instruction of an internal routine of a compiled method. The caller has
   already given the routine its own variable pool with the EXPOSE names shared (see HybridFunctionCall~internalCall);
   reached any other way (fall-through, SIGNAL) it is error 17.1, as interpreted. */
::class RxHybridProcedure public
::method accepts
  use arg ctx
  return ctx~stream~is('PROCEDURE') & ctx~stream~lookAheadText(1) \== '='
::method emit
  use arg ctx
  s = ctx~stream
  s~expect('PROCEDURE')
  if \ctx~current~hasInternalCalls then s~fail('PROCEDURE is valid only as the first instruction of an internal routine')
  if s~accept('EXPOSE') then do while s~peek~kind == 'IDENT'
    s~next
  end
  s~separator
  ctx~current~addRaw('if (!_rxInternal) throw rx::SyntaxCondition("17.1", "PROCEDURE is valid only when it is the first instruction executed after an internal CALL or function invocation", false);')
