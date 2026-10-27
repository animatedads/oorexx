/* scope_lock_threads.rex: guarded methods of one compiled object from four threads (ScopeLock taken without a mutex when free); GUARD WHEN hand-off between threads */
c = .Counter~new
msgs = .array~new
do t = 1 to 4
  msgs~append(.message~new(c, "BUMPMANY", "I", 3000)~~start)
end
do m over msgs; m~wait; end
say "count" c~count
q = .Queue2~new
consumer = .message~new(q, "TAKEALL", "I", 500)~~start
do i = 1 to 500; q~put(i); end
consumer~wait
say "sum" consumer~result
::class Counter
::method init
  expose n
  n = 0
::method bump
  expose n
  n = n + 1
::method bumpMany
  use arg k
  do k; self~bump; end
::method count
  expose n
  return n
::class Queue2
::method init
  expose items
  items = .array~new
::method put
  expose items
  use arg v
  items~append(v)
::method takeAll
  expose items
  use arg k
  s = 0
  do k
    guard on when items~items > 0
    s = s + items[1]; items~delete(1)
    guard off
  end
  return s
