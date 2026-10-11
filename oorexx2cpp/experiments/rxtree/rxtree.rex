/* rxtree: source map of a Rexx file AND its whole ::requires tree, from the interpreter's own objects.
   Every package (the file, then each dependency, depth first) is inspected the same way:
   - the program text before the first directive becomes the body of a synthetic ::method main (never run);
   - every dependency is copied into a scratch dir with ::options noprolog (its prologue never runs) and class-side
     INIT renamed (it would run when the class is installed); relative ::requires resolve against that dir;
   - a ::requires that cannot be found anywhere is blanked and reported (the program could not run here either).
   Output rows are TSV, each prefixed by the package they belong to. */
parse arg file
base = value('TMPDIR',,'ENVIRONMENT'); if base == '' then base = '/tmp'
tmp = .File~new(base'/rxtree.'time('F')'.'random(1,999999))
tmp~makeDirs
oldDir = directory()
ctx = .directory~new
ctx~tmp = tmp; ctx~opened = .set~new; ctx~missing = .list~new; ctx~order = .list~new; ctx~edges = .list~new
mainName = .File~new(file)~absolutePath
src = .stream~new(file)~arrayIn
call openDeps ctx, file, src, .File~new(file)~parent
call directory tmp~absolutePath
status = 0
status = inspectOne(ctx, mainName, neutralise(blankMissing(ctx, src), .false))
do d over ctx~order
  r = inspectOne(ctx, d, .stream~new(tmp~absolutePath'/'d)~arrayIn)
  if r \== 0 then status = r
end
call directory oldDir
do m over ctx~missing; say 'missing'||'09'x||m; end
do e over ctx~edges; say 'edge'||'09'x||e; end
call cleanup tmp
exit status

/* ---- the dependency tree ---- */
openDeps: procedure
  use arg ctx, owner, lines, base
  do l over lines
    t = l~strip
    if t~translate~left(11) \== '::REQUIRES ' then iterate
    parse var t . name .
    name = name~strip("B", "'")~strip("B", '"')
    if t~translate~word(3) == 'LIBRARY' then iterate
    ctx~edges~append(.File~new(owner)~name'09'x||name)
    if ctx~opened~hasIndex(name) then iterate
    ctx~opened~put(name)
    f = .File~new(name, base)
    if \f~exists then f = .File~new(name)
    if \f~exists then do
      found = SysSearchPath('REXX_PATH', name); if found == '' then found = SysSearchPath('PATH', name)
      if found \== '' then f = .File~new(found)
    end
    if \f~exists then do; ctx~missing~append(name); iterate; end
    dep = .stream~new(f~absolutePath)~arrayIn
    call openDeps ctx, name, dep, f~parent
    dep = neutralise(blankMissing(ctx, dep), .true)
    target = .File~new(ctx~tmp~absolutePath'/'name)
    target~parentFile~makeDirs
    out = .stream~new(target~absolutePath)
    out~open('write replace')
    do x over dep; out~lineout(x); end
    out~close
    ctx~order~append(name)
  end
  return

blankMissing: procedure
  use arg ctx, lines
  r = .array~new
  do l over lines
    t = l~strip
    if t~translate~left(11) == '::REQUIRES ' then do
      parse var t . nm .; nm = nm~strip("B", "'")~strip("B", '"')
      do m over ctx~missing; if m == nm then l = '-- (missing) ' l; end
    end
    r~append(l)
  end
  return r

/* class-side INIT renamed; a dependency also gets ::options noprolog right before its first directive */
neutralise: procedure
  use arg lines, isDep
  r = .array~new; placed = \isDep
  do l over lines
    u = l~strip~translate
    if \placed, u~left(2) == '::' then do; r~append('::options noprolog'); placed = .true; end
    if u~left(14) == '::METHOD INIT ', u~pos(' CLASS') > 0 then l = l~changeStr(l~substr(l~translate~pos(' INIT ') + 1, 4), 'RXTREE_INIT')
    r~append(l)
  end
  if \placed then r~append('::options noprolog')
  return r

cleanup: procedure
  use arg dir
  do f over dir~listFiles; if f~isDirectory then call cleanup f; else f~delete; end
  dir~delete
  return

/* ---- one package ---- */
inspectOne: procedure
  use arg ctx, label, src
  w = .array~of('::class __RXP', '::method main')
  s1 = src~copy
  if s1~items > 0, s1[1]~left(2) == '#!' then s1[1] = '--' s1[1]
  w~appendAll(s1)
  signal on syntax name bad
  /* the package is named INSIDE the scratch dir so its relative ::requires find the neutralised copies */
  inner = label; if inner~left(1) == '/' then inner = '__main__.rex'
  p = .Package~new(ctx~tmp~absolutePath'/'inner, w)
  signal off syntax
  used = .set~new
  say 'package'||'09'x||label||'09'x||'digits='p~digits 'fuzz='p~fuzz 'form='p~form 'prolog='p~prolog
  do r over p~importedPackages
    say 'requires'||'09'x||label||'09'x||r~name
  end
  call emit 'prologue', 'main', '', p~findClass('__RXP')~method('MAIN')~source
  do c over p~classes~allIndexes~sort
    if c == '__RXP' then iterate
    cls = p~findClass(c)
    vis = 'private'; if p~publicClasses~hasIndex(c) then vis = 'public'
    extra = 'super='cls~superclass~id
    if cls~isAbstract then extra = extra 'abstract'
    if cls~queryMixinClass then extra = extra 'mixin'
    extra = extra 'supers='cls~superclasses~items
    call emit 'class', c, vis extra, .array~new
    do m over cls~methods(.nil)~allIndexes~sort
      call emitMethod 'method', c'~'m, cls~method(m)
    end
    /* inheritance chain and method resolution, as the interpreter resolves it (first owner wins; overridden entries follow) */
    chain = cls~id; k = cls
    do while k~superclass \== .nil
      k = k~superclass; chain = chain'>'k~id
    end
    mix = ''; do sc over cls~superclasses~allItems; if sc~queryMixinClass then mix = mix sc~id; end
    say 'chain'||'09'x||label||'09'x||c||'09'x||chain||'09'x||'mixins:'mix~strip
    rs = cls~methods
    do while rs~available
      if rs~item~scope \== .Object then say 'resolves'||'09'x||label||'09'x||c'~'rs~index||'09'x||rs~item~scope~id
      rs~next
    end
    sup = cls~instanceMethods   /* class-side (::method x class) methods live here */
    do while sup~available
      if sup~item~scope == cls then call emitMethod 'class-method', c'~'sup~index~changeStr('RXTREE_INIT', 'INIT'), sup~item
      sup~next
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
bad:
  c = condition('O'); say 'COMPILE-ERROR'||'09'x||label||'09'x||c~message
  return 1

emitMethod: procedure expose w used label
  use arg kind, name, mm
  d = ''
  if mm~isPrivate then d = d 'private'
  if mm~isPackage then d = d 'package'
  if mm~isProtected then d = d 'protected'
  if mm~isAttribute then d = d 'attribute'
  if mm~isConstant then d = d 'constant'
  if mm~isAbstract then d = d 'abstract'
  if \mm~isGuarded then d = d 'unguarded'
  call emit kind, name, strip(d), mm~source
  return

emit: procedure expose w used label
  use arg kind, name, detail, block
  start = ''; end = ''
  n = block~items
  if n > 0 then do
    do i = 3 to w~items - n + 1 while start == ''
      ok = .true
      do j = 1 to n while ok
        if w[i + j - 1] \== block[j] then ok = .false
      end
      if ok & \used~hasIndex(i) then do
        start = i - 2; end = i - 2 + n - 1; used~put(i)
      end
    end
  end
  say kind||'09'x||label||'09'x||name||'09'x||detail||'09'x||start||'09'x||end
  return
