/* REPLY in compiled methods: the caller gets the value and goes on while the method runs on (guarded: the object
   stays locked until the method ends, so a guarded STATUS call waits for it). */
::class Replier public
::method init
  expose log
  log = ''
::method status
  expose log
  return log
::method plain
  expose log
  reply 'r1'
  log = log 'after-plain'
::method bare
  expose log
  reply
  log = log 'after-bare'
::method noReply
  return 'returned'
::method noValue
  expose log
  log = log 'novalue'
::method args
  expose log
  reply arg()
  log = log 'args' arg() arg(2, 'O') .context~args~size
::method twice
  expose log
  signal on syntax
  reply 'one'
  reply 'two'
  log = log 'not here'
  return
syntax:
  log = log 'twice' condition('O')~code
::method returnAfter
  expose log
  signal on syntax
  reply 'ra'
  return 'x'
syntax:
  log = log 'returnAfter' condition('O')~code
::method exitAfter
  expose log
  signal on syntax
  reply 'ea'
  exit 'x'
syntax:
  log = log 'exitAfter' condition('O')~code
::method internal
  expose log
  signal on syntax
  call sub
  return 'internal-returned'
sub:
  reply 'fromsub'
  return 'no'
syntax:
  log = log 'internal' condition('O')~code
  return 'trapped'
::method internalReturn
  expose log
  reply 'ir'
  call sub
  log = log 'sub gave' result
  return
sub:
  return 'subval'
::method before
  x = 1 / 0
  reply 'never'
::method unguardedOne unguarded
  expose log
  reply 'u'
  log = log 'after-unguarded'
::method outer
  expose log
  v = self~innerReply
  log = log 'outer-got' v
  return 'outer-done'
::method innerReply
  expose log
  reply 'inner'
  log = log 'inner-after'
::method classSide class
  reply 'class-reply'
::routine rr public
  reply 5
