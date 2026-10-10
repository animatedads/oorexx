/* TAG: KERNEL_LOCK_DEPENDENT. UNGUARDED method, shared variable, no synchronisation.
   Interpreter result is exact because activities are serialised. A parallel native
   build may legitimately differ; a compatibility-mode build must match. */
c = .C~new
msgs = .array~new
do 4; msgs~append(c~start("BUMP", 100000)); end
do m over msgs; m~result; end
say "unguarded total" c~n
::class C
::attribute n
::method init; expose n; n = 0
::method bump unguarded
  expose n
  use arg k
  do k; n = n + 1; end
  return 0
