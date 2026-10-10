/* ooRexx conversion driver. Usage: from pack root, with real upstream source.
   100% discovery/routing ONLY when full BUILTIN source is supplied. */
parse arg sourceFile outdir
if sourceFile == '' | outdir == '' then do
  say 'Usage: rexx bif2breadth.rex /source/BuiltinFunctions.cpp /existing/output-dir'
  exit 64
end
signal on syntax name failed
signal on error name failed
signal on failure name failed
if stream(sourceFile,'C','QUERY EXISTS') == '' then do
  say 'Missing upstream source:' sourceFile
  exit 66
end
reader = .BifSourceReader~new
sourceEntries = reader~scan(sourceFile)
rule = .BifBreadthRouteRule~new
accepted = .array~new
report = .array~new
report~append('name' || '09'x || 'route' || '09'x || 'source_line' || '09'x || 'status')
seen = .directory~new
failed = 0
do definition over sourceEntries
  name = definition~name
  if seen~hasIndex(name) then do
    say 'Duplicate upstream BUILTIN macro:' name
    exit 65
  end
  seen[name] = .true
  ir = rule~convert(definition)
  if ir == .nil then do
    failed += 1
    report~append(name || '09'x || 'REJECTED' || '09'x || definition~line || '09'x || 'source or arity drift')
  end
  else do
    accepted~append(ir)
    report~append(name || '09'x || ir~kind || '09'x || definition~line || '09'x || 'ADMITTED')
  end
end
catalog = rule~catalogue
missing = 0
do name over catalog~names
  if \seen~hasIndex(name) then do
    missing += 1
    report~append(name || '09'x || 'MISSING' || '09'x || '-' || '09'x || 'not found in source')
  end
end
if accepted~items == 0 then do
  say 'No BIFs accepted; no output generated'
  exit 65
end
emitter = .BifBreadthEmitter~new
emitter~emit(accepted, report, outdir)
say 'BIF route coverage:' accepted~items '/' catalog~count 'missing:' missing 'rejected:' failed
if failed > 0 | missing > 0 then exit 3
exit 0
failed:
  say 'BIF source conversion failed:' condition('O')~at('MESSAGE')
  exit 70
::requires 'compiler/BifSourceReader.cls'
::requires 'rules/BifBreadthRouteRule.cls'
::requires 'compiler/BifBreadthEmitter.cls'
