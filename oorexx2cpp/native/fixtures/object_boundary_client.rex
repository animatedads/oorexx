/* Interpreted driver of the same fixture class in both paths. */
p = .BridgeProbe~new
methodFound = 0
methods = p~class~methods
published = .directory~new
do while methods~available
  published[methods~index] = 1
  if methods~index == 'ECHO' then methodFound = 1
  methods~next
end
say 'class method visible:' methodFound
complete = 1
do name over 'INIT ECHO STASH FETCH MAKE REPLACE CALLBACK BOUNCE OPTIONAL'~makeArray(' ')
  if \published~hasIndex(name) then complete = 0
end
say 'declared method inventory:' complete
cb = .Callback~new
arr = .array~of('one')
dir = .directory~new
dir~put(arr, 'saved')
li = .list~new
li~append(dir)
say 'array identity:' (p~echo(arr) == arr)
say 'directory identity:' (p~echo(dir) == dir)
say 'list identity:' (p~echo(li) == li)
say 'nil identity:' (p~echo(.nil) == .nil)
say 'self identity:' (p~stash(arr) == p)
say 'stored identity:' (p~fetch == arr)
say 'shared nested identity:' (dir~at('saved') == p~fetch)
identityTable = .identityTable~new
identityTable~put('kept', arr)
say 'identity table roundtrip:' identityTable~at(p~echo(arr))
say 'returned array:' p~make('created')~at(1) p~make('created')~class~id
say 'default missing:' p~optional
say 'explicit nil:' (p~optional(.nil) == .nil)
say 'replace identity:' (p~replace(arr, 'two') == arr) arr~at(1)
say 'interpreted callback identity:' (p~callback(cb, dir) == dir)
say 'nested compiled-interpreted-compiled identity:' (p~bounce(cb, li) == li)
say 'object as argument identity:' (p~echo(p) == p)
fail = 0
do i = 1 to 600
  v = .array~of(i)
  p~stash(v)
  if p~fetch \== v then fail += 1
  if p~echo(v) \== v then fail += 1
  if p~callback(cb, v) \== v then fail += 1
  if p~bounce(cb, v) \== v then fail += 1
end
say 'reference replacement 2400:' fail
/* These methods are ALWAYS interpreted. They deliberately call back into the
 * compiled BridgeProbe to exercise nested entry/exit and object identity. */
::class Callback public
::method echo
  use arg obj
  return obj
::method bounce
  use arg nativeObject, obj
  return nativeObject~echo(obj)
