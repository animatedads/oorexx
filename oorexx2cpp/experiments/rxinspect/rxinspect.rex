/* rxinspect: source map of a Rexx file from the interpreter's own objects. No parsing of Rexx here.
   1. copy the file with '::class __RXP' + '::method main' in front, so the main program becomes a method body
      (compiled, never run);  2. let ooRexx compile it;  3. read classes/methods/routines/options back. */
parse arg file
src = .stream~new(file)~arrayIn
/* rule 1: a #! first line is only legal at the very start of a file; blank it to a comment, same line count */
if src~items > 0, src[1]~left(2) == '#!' then src[1] = '--' src[1]
w = .array~of('::class __RXP', '::method main')
w~appendAll(src)
signal on syntax name bad
p = .Package~new('inspect', w)
signal off syntax
used = .set~new
say 'package'||'09'x||p~name||'09'x||'digits='p~digits 'fuzz='p~fuzz 'form='p~form 'prolog='p~prolog
do r over p~importedPackages
  say 'requires'||'09'x||r~name
end
main = p~findClass('__RXP')~method('MAIN')
call emit 'prologue', 'main', '', main~source
do c over p~classes~allIndexes~sort
  if c == '__RXP' then iterate
  cls = p~findClass(c)
  vis = 'private'; if p~publicClasses~hasIndex(c) then vis = 'public'
  sup = cls~superclasses~allItems~makeString('l', ',')
  extra = 'super='cls~superclass~id
  if cls~isAbstract then extra = extra 'abstract'
  if cls~queryMixinClass then extra = extra 'mixin'
  extra = extra 'supers='cls~superclasses~items
  call emit 'class', c, vis extra, .array~new
  do m over cls~methods(.nil)~allIndexes~sort
    mm = cls~method(m)
    d = ''
    if mm~isPrivate then d = d 'private'
    if mm~isPackage then d = d 'package'
    if mm~isProtected then d = d 'protected'
    if mm~isAttribute then d = d 'attribute'
    if mm~isConstant then d = d 'constant'
    if \mm~isGuarded then d = d 'unguarded'
    call emit 'method', c'~'m, strip(d), mm~source
  end
end
do rn over p~routines~allIndexes~sort
  vis = 'private'; if p~publicRoutines~hasIndex(rn) then vis = 'public'
  call emit 'routine', rn, vis, p~routines[rn]~source
end
do m over p~definedMethods~allIndexes~sort
  call emit 'unattached-method', m, '', p~definedMethods[m]~source
end
return 0
bad: c = condition('O'); say 'COMPILE-ERROR'||'09'x||c~message; exit 1

emit: procedure expose w used
  use arg kind, name, detail, block
  start = ''; end = ''
  n = block~items
  if n > 0 then do
    do i = 3 to w~items - n + 1 while start == ''   -- 3 = skip the two wrapper lines
      ok = .true
      do j = 1 to n while ok
        if w[i + j - 1] \== block[j] then ok = .false
      end
      if ok & \used~hasIndex(i) then do
        start = i - 2; end = i - 2 + n - 1; used~put(i, i)
      end
    end
  end
  say kind||'09'x||name||'09'x||detail||'09'x||start||'09'x||end
  return
