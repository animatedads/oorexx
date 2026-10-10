/* One or two positional scalar arguments; omitted/extra positions fail closed. */
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
  if s~accept(',') then do
    if s~peek~kind \= 'IDENT' then s~fail('second USE ARG parameter must be a simple variable')
    ctx~current~setSecondParameter(s~next~text)
    if s~is(',') then s~fail('native methods support at most two USE ARG parameters')
  end
  s~separator
