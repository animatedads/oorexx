/* The interpreted table: which classes / methods of a native package the interpreter runs instead of compiled code.

   File: <package>.rx2cpp next to the source, or RX2CPP_TABLE=path. One rule per line; blank lines and lines starting
   with # or -- are ignored. Words are separated by blanks; names are not case sensitive.

     prefer_interpreted   Class                 the whole class runs interpreted
     prefer_interpreted   Class  *              the same
     prefer_interpreted   Class  method         one instance method runs interpreted
     prefer_interpreted   Class  method  CLASS  one class method runs interpreted
     requires_interpreted ...                   the same forms
     interpreted_form tokenized | source | file how the interpreted parts are carried (once per table)

   interpreted_form (default tokenized):
     tokenized  the library's declaration package (compiled class stubs, interpreted classes and methods, prolog) is
                tokenized by rexxc at build time and the image is embedded: no parse when the library loads.
     source     the declaration package is embedded as source text and parsed when the library loads.
     file       the interpreted parts are written to <library>_interpreted.cls next to the library and read from
                there every time the library loads: edit that file, reload, and the change is live. Marker lines
                /* #REXX2CPP METHODS class */ and /* #REXX2CPP CLASSES */ say where each part belongs; keep them.

   prefer_interpreted:   interpreted if possible; otherwise a warning and the code is compiled.
   requires_interpreted: interpreted, or the build fails. A rule that matches nothing: warning (prefer) / error (requires).

   A whole class is always possible: its source goes unchanged into the library's declaration package (object
   variables are per class scope in ooRexx, so compiled and interpreted classes never share variables).
   One method is possible only when it shares no variables with the compiled methods of its class: no EXPOSE,
   not INIT / UNINIT, not an ::ATTRIBUTE. */
::class RxNativeInterpretedTable public
::attribute rules get
::attribute path get
::attribute form get
::method init
  expose rules path form
  use arg path = ''
  rules = .array~new
  form = 'tokenized'
  formLine = 0
  if path == '' then return
  if stream(path, 'C', 'QUERY EXISTS') == '' then raise syntax 40.1 array('rx2cpp: interpreted table not found ' || path)
  lineNo = 0
  do while lines(path) > 0
    line = linein(path)
    lineNo += 1
    text = line~strip
    if text == '' | text~left(1) == '#' | text~left(2) == '--' then iterate
    parse var text mode className methodName side extra
    mode = mode~lower
    if mode == 'interpreted_form' then do
      if formLine > 0 then raise syntax 40.1 array('rx2cpp: interpreted table line' lineNo': interpreted_form already set on line' formLine)
      if wordpos(className~lower, 'tokenized source file') == 0 | methodName \== '' then
        raise syntax 40.1 array('rx2cpp: interpreted table line' lineNo': interpreted_form takes tokenized, source or file')
      form = className~lower
      formLine = lineNo
      iterate
    end
    if mode \== 'prefer_interpreted' & mode \== 'requires_interpreted' then
      raise syntax 40.1 array('rx2cpp: interpreted table line' lineNo': expected prefer_interpreted or requires_interpreted, found' mode)
    if className == '' then raise syntax 40.1 array('rx2cpp: interpreted table line' lineNo': class name missing')
    if extra \== '' then raise syntax 40.1 array('rx2cpp: interpreted table line' lineNo': unexpected' extra)
    if side \== '' & side~upper \== 'CLASS' then
      raise syntax 40.1 array('rx2cpp: interpreted table line' lineNo': expected CLASS after the method name, found' side)
    if methodName == '*' then methodName = ''
    if methodName == '' & side \== '' then raise syntax 40.1 array('rx2cpp: interpreted table line' lineNo': CLASS needs a method name')
    rule = .directory~new
    rule~mode = mode~left(mode~pos('_') - 1)       /* prefer | requires */
    rule~className = className~strip('B', '"')~strip('B', "'")~upper
    rule~methodName = methodName~strip('B', '"')~strip('B', "'")~upper
    rule~classSide = side \== ''
    rule~line = lineNo
    rule~used = .false
    rules~append(rule)
  end
  call stream path, 'C', 'CLOSE'
/* The rule for a whole class, or .nil. */
::method classRule
  expose rules
  use arg className
  do rule over rules
    if rule~className == className~upper & rule~methodName == '' then do
      rule~used = .true
      return rule
    end
  end
  return .nil
/* The rules naming one method of this class: an array of rules. */
::method methodRules
  expose rules
  use arg className
  found = .array~new
  do rule over rules
    if rule~className == className~upper & rule~methodName \== '' then found~append(rule)
  end
  return found
/* A rule that cannot be honoured: warning for prefer, build failure for requires. */
::method refuse
  use arg rule, reason
  where = 'rx2cpp: interpreted table line' rule~line '('rule~mode'_interpreted' rule~className rule~methodName')'
  if rule~mode == 'requires' then raise syntax 40.1 array(where || ':' reason)
  .error~lineout(where || ': warning:' reason '- compiled instead')
/* After parsing: every rule must have matched something. */
::method checkUnused
  expose rules
  do rule over rules
    if \rule~used then self~refuse(rule, 'no such class or method in the package')
  end
::method report
  expose rules
  do rule over rules
    side = ''
    if rule~classSide then side = ' CLASS'
    if rule~used & rule~honoured == .true then
      .error~lineout('rx2cpp: interpreted:' (rule~className rule~methodName)~strip || side '('rule~mode')')
  end
