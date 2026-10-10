/* start N messages, collect results in submission order */
o = .W~new
msgs = .array~new
do i = 1 to 8; msgs~append(o~start("SQUARE", i)); end
do m over msgs; say m~result; end
::class W
::method square unguarded
  use arg n
  return n * n
