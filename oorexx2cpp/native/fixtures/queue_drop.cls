/* DROP (simple, stem, compound under a default, indirect list), PUSH / QUEUE / PULL / PARSE PULL, a lone period,
   and a symbol-first command clause, in a compiled library. */
::class QueueDrop public
::method drops
  a = 1; b.1 = 2; b. = 'D'; b.3 = 'E'; c.1 = 5; j = 1; k = 'j C.1'
  drop a b.3
  r = a b.3 b.4 var('A') var('B.3') var('B.4') symbol('B.3')
  drop b.
  r = r '|' b.1 b. var('B.') symbol('B.1')
  drop (k)
  r = r '|' c.1 var('J') k
  return r
::method queues
  push 'pushed line'
  queue 'queued line'
  queue
  n = queued()
  pull first
  parse pull second
  pull
  return n first '|' second '|' queued()
::method pullTemplate
  queue 'alpha beta gamma'
  queue 'one two'
  i = 2
  pull x (i) .
  pull answer .
  return x '|' answer
::method emptyTail
  s. = 'D'; t = ''
  r = s.t var('S.T')
  s.t = 'E'
  r = r s. s.t s.x var('S.T') symbol('S.T') value('S.T')
  drop s.t
  r = r s.t s. var('S.T')
  u.t = 'only'
  return r '|' u. u.t var('U.') var('U.T')
::method dots
  return xrange(., .) strip(., , .) length(.)
::method command
  echoIt = 'echo'
  echoIt 'compiled command'
  return rc
