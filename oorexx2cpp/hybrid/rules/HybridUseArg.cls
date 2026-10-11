/* USE ARG binds simple variables to argument positions 1..N (the ARGLIST is an array). */
::class RxHybridUseArg public
::method accepts
  use arg ctx
  return ctx~stream~is('USE')
::method emit
  use arg ctx
  s = ctx~stream
  s~expect('USE'); s~expect('ARG')
  if ctx~current~seenStatement | ctx~current~parameter \== '' then s~fail('USE ARG may occur only once before statements')
  if s~peek~kind \= 'IDENT' then s~fail('USE ARG requires one simple variable')
  ctx~current~setParameter(s~next~text)
  /* Arguments are an array: bind names to positions 1..N, any N. */
  do while s~accept(',')
    if s~peek~kind \= 'IDENT' then s~fail('USE ARG parameter must be a simple variable')
    ctx~current~addParameter(s~next~text)
  end
  s~separator
