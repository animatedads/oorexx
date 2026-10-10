/* guarded (default) method: no lost updates by contract */
c = .C~new
msgs = .array~new
do 4; msgs~append(c~start("BUMP", 100000)); end
do m over msgs; m~result; end
say "guarded total" c~n
::class C
::attribute n
::method init; expose n; n = 0
::method bump
  expose n
  use arg k
  do k; n = n + 1; end
  return 0
