/* interpreter objects at the addresses of collected objects of compiled instances are themselves */
make = .routine~new('make', 'use arg n; a = .array~new(n); do i = 1 to n; a[i] = .directory~new; end; return a')
churn = .routine~new('churn', 'do i = 1 to 20000; s = .array~of(i, i, i); end; return 0')
bad = 0
do round = 1 to 30
  a = .array~new
  do i = 1 to 300; a~append(.node~new(i)); end
  .local['HOLD'] = a          -- the nodes get interpreter objects
  .local~remove('HOLD')
  drop a
  churn~call                  -- the interpreter collects them
  dirs = make~call(600)       -- new interpreter objects, some at those addresses
  do d over dirs
    if d~class \== .directory then bad += 1
  end
end
say 'wrong objects:' bad
exit
::class node
::method init
  expose v
  use arg v
