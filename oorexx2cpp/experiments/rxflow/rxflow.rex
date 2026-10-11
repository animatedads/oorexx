/* rxflow: sandboxed, branch-forced model of a Rexx program's call flow. No Rexx parsing beyond line rules.
   usage: rexx rxflow.rex file.rex [maxRuns]
   Layers: (1) unit map from interpreter objects; (2) SecurityManager blocks COMMAND/CALL/STREAM/etc.;
   (3) interceptor labels shadow the I/O BIFs (an internal label beats a built-in); (4) IF/WHEN/WHILE/UNTIL/FOREVER tests
   are replaced by __F(line,kind), whose answers come from an explored decision vector; (5) SAY + TRACE are captured. */
parse arg file maxRuns
if maxRuns == '' then maxRuns = 24
orig = .stream~new(file)~arrayIn
if orig~items > 0, orig[1]~left(2) == '#!' then orig[1] = '--' orig[1]
blocked = .list~new                    /* requires removed */
do i = 1 to orig~items                 /* ::requires would execute other programs outside the sandbox */
  if orig[i]~strip~translate~left(11) == '::REQUIRES ' then do
    blocked~append('line' i':' orig[i]~strip); orig[i] = '-- (blocked) ' orig[i]
  end
end
units = mapUnits(orig)
if units == .nil then exit 1
say 'file' file '-' orig~items 'lines,' units~items 'code units; requires blocked:' blocked~items
do b over blocked; say '  ' b; end

queue = .queue~new; queue~queue(.array~new); seen = .set~new
allEdges = .directory~new; reached = .set~new; effects = .directory~new; sites = .directory~new
runs = 0
do while queue~items > 0 & runs < maxRuns
  plan = queue~pull
  runs = runs + 1
  res = runOnce(orig, units, plan)
  dec = res~decisions
  path = ''; do d over dec; path = path || d~v; end
  say 'run' runs 'plan='plan~items 'decisions='path~left(60) 'flow='res~flow~left(120)
  if res~error \== '' then say '    ended with:' res~error
  do u over res~units; reached~put(u); end
  do e over res~edges; allEdges[e] = nz(allEdges~at(e)) + 1; end
  do e over res~effects; effects[e] = nz(effects~at(e)) + 1; end
  do d over dec; old = sites~at(d~line d~kind); if old == .nil then old = ''; sites[d~line d~kind] = old||d~v; end
  /* explore: flip each decision after the forced prefix */
  do i = plan~items + 1 to dec~items
    np = .array~new
    do j = 1 to i - 1; np~append(dec[j]~v); end
    np~append(\dec[i]~v)
    key = np~makeString('l', '')
    if \seen~hasIndex(key) then do; seen~put(key); queue~queue(np); end
  end
end
say; say 'runs:' runs 'queued-unexplored:' queue~items
say 'units reached:' reached~items 'of' units~items
do u over units; if \reached~hasIndex(u~label) then say '  not reached:' u~label; end
say 'call-flow edges (caller > callee, count):'
do e over allEdges~allIndexes~sort; say '  'e allEdges[e]; end
say 'external effects intercepted:'
do e over effects~allIndexes~sort; say '  'e 'x'effects[e]; end
say 'decision sites (line kind: values seen):'
do e over sites~allIndexes~sort; say '  'e':' sites[e]; end
exit 0

nz: procedure
  use arg x
  if x == .nil then return 0
  return x

/* ---- unit map: classes' methods, routines, main program, from interpreter objects ---- */
mapUnits: procedure
  use arg orig
  w = .array~of('::class __RXP', '::method main'); w~appendAll(orig)
  signal on syntax name bad
  p = .Package~new('map', w)
  signal off syntax
  units = .list~new; used = .set~new
  call addUnit units, used, w, 'main program', 'prologue', p~findClass('__RXP')~method('MAIN')~source
  do c over p~classes~allIndexes~sort
    if c == '__RXP' then iterate
    cls = p~findClass(c)
    do m over cls~methods(.nil)~allIndexes~sort
      call addUnit units, used, w, c'~'m, 'method', cls~method(m)~source
    end
  end
  do rn over p~routines~allIndexes~sort
    call addUnit units, used, w, rn, 'routine', p~routines[rn]~source
  end
  return units~allItems
bad: c = condition('O'); say 'COMPILE-ERROR' c~message; return .nil

addUnit: procedure
  use arg units, used, w, label, kind, block
  n = block~items
  if n == 0 then return
  do i = 3 to w~items - n + 1
    ok = .true
    do j = 1 to n while ok
      if w[i + j - 1] \== block[j] then ok = .false
    end
    if ok & \used~hasIndex(i) then do
      used~put(i)
      units~append(.Unit~new(label, kind, i - 2, i - 2 + n - 1)); return
    end
  end
  return

/* ---- build the instrumented source and run it once under the sandbox ---- */
runOnce: procedure
  use arg orig, units, plan
  lines = .array~new; origOf = .array~new
  endsAt = .directory~new            /* original line -> unit ends there */
  do u over units; endsAt[u~end] = u; end
  lines~append('::class __RXP'); origOf~append(0)
  lines~append('::method main'); origOf~append(0)
  do i = 1 to orig~items
    lines~append(force(orig[i], i)); origOf~append(i)
    if endsAt~hasIndex(i) then do
      icpt = 'return'
      do bif over 'LINEOUT CHAROUT LINEIN CHARIN STREAM LINES CHARS DIRECTORY CHDIR'~makeArray(' ')
        icpt = icpt';' bif": return __rxio('"bif"', .context~args)"
      end
      do part over icpt~makeArray(';'); lines~append(part~strip); origOf~append(0); end
    end
  end
  helper = '::routine __F;use arg ln, kind;return .__RXF~decide(ln, kind)', -
           '::routine __rxio;use arg nm, a;return .__RXF~effect(nm, a)', -
           '::class __RXF', -
           '::attribute plan class', '::attribute log class', '::attribute fx class', '::attribute visits class', '::attribute n class', -
           '::method decide class;expose plan log visits n;use arg ln, kind;n = n + 1;v0 = visits~at(ln kind);if v0 == .nil then v0 = 0;visits[ln kind] = v0 + 1;', -
           'if n <= plan~items then v = plan[n]; else v = 0;', -
           'if kind == "W" & visits[ln kind] > 2 then v = 0;if kind == "U" & visits[ln kind] > 2 then v = 1;', -
           'log~append(.Decision~new(ln, kind, v));return v', -
           '::method effect class;expose fx;use arg nm, a;fx~append(nm);return ""'
  do h over helper
    do part over h~makeArray(';'); lines~append(part); origOf~append(0); end
  end
  /* package-local classes named like the dangerous built-ins win over the built-ins for this package's code */
  do cn over 'STREAM FILE RexxQueue Socket'~makeArray(' ')
    gen = '::class' cn, '::method init', 'expose nm', 'use arg nm = ""', '::method unknown', 'expose nm', 'use arg mn, ma', -
          'return .__RXF~effect("'cn'~"mn, nm)'
    do part over gen
      lines~append(part); origOf~append(0)
    end
  end
  lines~append('::class Decision'); origOf~append(0)
  lines~append('::attribute line'); origOf~append(0)
  lines~append('::attribute kind'); origOf~append(0)
  lines~append('::attribute v'); origOf~append(0)
  lines~append('::method init;expose line kind v;use arg line, kind, v'); origOf~append(0)
  lines~append('::options trace R'); origOf~append(0)
  src = .array~new
  do l over lines; do part over l~makeArray(';'); src~append(part); end; end
  /* the line count changed if any original line contained ';' -> keep a per-physical-line origin map instead */
  src = .array~new; ofn = .array~new
  do k = 1 to lines~items
    if origOf[k] == 0 then do p2 over lines[k]~makeArray(';'); src~append(p2); ofn~append(0); end
    else do; src~append(lines[k]); ofn~append(origOf[k]); end
  end
  res = .Result~new
  cap = .Cap~new
  mgr = .Sandbox~new(res)
  saveOut = .local~output; saveTr = .local~traceoutput
  .local~output = cap; .local~traceoutput = cap
  signal on syntax name compileFail
  p = .Package~new('flow', src)
  signal off syntax
  p~setSecurityManager(mgr)
  hc = p~findClass('__RXF')
  hc~plan = plan; hc~log = .list~new; hc~fx = .list~new; hc~visits = .directory~new; hc~n = 0
  signal on syntax name runFail
  o = p~findClass('__RXP')~new
  o~main
  runFail:
  if condition('C') == 'SYNTAX' then res~error = condition('O')~message
  trace off
  .local~output = saveOut; .local~traceoutput = saveTr
  res~decisions = hc~log~allItems
  do e over hc~fx; res~effects~append('intercepted' e); end
  do e over mgr~log; res~effects~append('manager' e); end
  /* trace -> flow of units */
  prev = ''; flow = ''
  do t over cap~lines
    parse var t num '*-*' .
    if \datatype(num~strip, 'W') | t~pos('*-*') == 0 then iterate
    src_line = ofn[num~strip]
    if src_line == .nil | src_line == 0 then iterate
    u = unitOf(units, src_line)
    if u == '' then iterate
    if u \== prev then do
      res~units~append(u); flow = flow u
      if prev \== '' then res~edges~append(prev '>' u)
      prev = u
    end
  end
  res~flow = flow~strip~changeStr(' ', ' ')
  return res
compileFail:
  .local~output = saveOut; .local~traceoutput = saveTr
  res = .Result~new; res~error = 'compile: ' || condition('O')~message
  return res

unitOf: procedure
  use arg units, ln
  do u over units; if ln >= u~start & ln <= u~end then return u~label; end
  return ''

/* replace the test of IF/WHEN/WHILE/UNTIL/FOREVER by __F(line,kind): same line, same length rules */
force: procedure
  use arg t, ln
  u = t~translate; s = u~strip
  q = ln'";'
  if s~left(3) == 'IF ' | s~left(5) == 'WHEN ' | s~left(8) == 'ELSE IF ' then do
    kw = u~pos(' IF ') ; if s~left(5) == 'WHEN ' then kw = u~pos('WHEN ') + 3; else if s~left(3) == 'IF ' then kw = u~pos('IF ') + 1
    tp = u~pos(' THEN', kw)
    if tp > 0 then return t~left(kw + 1) '__F('ln',"I")' t~substr(tp)
    return t
  end
  if s~word(1) == 'DO' | s~word(1) == 'LOOP' then do
    if u~pos(' FOREVER') > 0 then return t~left(u~pos(' FOREVER') - 1) 'WHILE __F('ln',"W")'
    wp = u~pos(' WHILE ')
    if wp > 0 then return t~left(wp - 1) 'WHILE __F('ln',"W")'
    up = u~pos(' UNTIL ')
    if up > 0 then return t~left(up - 1) 'UNTIL __F('ln',"U")'
  end
  return t

::class Unit
::attribute label
::attribute kind
::attribute start
::attribute end
::method init
  expose label kind start end
  use arg label, kind, start, end
::class Result
::attribute decisions
::attribute effects
::attribute units
::attribute edges
::attribute flow
::attribute error
::method init
  expose decisions effects units edges flow error
  decisions = .array~new; effects = .list~new; units = .list~new; edges = .list~new; flow = ''; error = ''
::class Cap
::method init
  expose lines
  lines = .list~new
::attribute lines
::method lineout
  expose lines
  use arg t = ''
  lines~append(t); return 0
::method charout
  expose lines
  use arg t = ''
  lines~append(t); return 0
::method say
  expose lines
  use arg t = ''
  lines~append(t)
::class Sandbox
::attribute log
::method init
  expose log
  log = .list~new
::method unknown
  expose log
  use arg name, args
  if wordpos(name, 'ENVIRONMENT LOCAL CLASS METHOD') > 0 then return .false   /* reading symbols like .context is harmless */
  d = args[1]
  detail = ''
  if d~isA(.Directory) then do i over d~allIndexes~sort; if i \== 'ARGUMENTS' then detail = detail i'='d[i]~string; end
  log~append('BLOCKED' name detail~strip)
  if name == 'STREAM' then d~put(.NullStream~new(d~at('NAME'), log), 'RESULT')   /* a stream object that only records */
  else d~put('', 'RESULT')
  return .true
::class NullStream
::method init
  expose name log
  use arg name, log
::method lineout
  expose name log
  use arg t = ''
  log~append('captured write to' name':' t); return 0
::method charout
  expose name log
  use arg t = ''
  log~append('captured write to' name':' t); return 0
::method linein
  return ''
::method charin
  return ''
::method chars
  return 0
::method lines
  return 0
::method state
  return 'READY'
::method description
  return 'NULL'
::method close
  return 'READY:'
::method open
  return 'READY:'
::method qualify
  expose name
  return name
::method unknown
  return ''
