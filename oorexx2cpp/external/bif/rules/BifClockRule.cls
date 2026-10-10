/* Clock-dependent BIFs require per-activation context. Source semantics
   DO NOT permit time() to read a fresh clock on every invocation. */
::class BifClockRule public
::method accept
  use arg def
  return def~name == 'DATE' | def~name == 'TIME'
::method convert
  use arg def
  name = def~name
  s = def~joined
  if pos('fix_args(' || name || ')',s) == 0 then return .nil
  if pos('RexxDateTime current = context->getTime()',s) == 0 then return .nil
  if pos('switch (style)',s) == 0 then return .nil
  if name == 'DATE' then do
    if def~minArg \= 0 | def~maxArg \= 5 then return .nil
    if pos('timestamp.parseISODate(',s) == 0 then return .nil
    if pos('timestamp.getBaseDate()',s) == 0 then return .nil
    if pos('timestamp.getBaseTime()',s) == 0 then return .nil
    if pos('timestamp.getUnixTime()',s) == 0 then return .nil
    if pos('timestamp.setTimeZoneOffset(',s) == 0 then return .nil
    if pos('timestamp.formatISODate(',s) == 0 then return .nil
    if pos('strchr("EINOSU", style)',s) == 0 then return .nil
  end
  else do
    if def~minArg \= 0 | def~maxArg \= 3 then return .nil
    if pos('timestamp.parseNormalTime(',s) == 0 then return .nil
    if pos('context->getElapsed()',s) == 0 then return .nil
    if pos('context->resetElapsed()',s) == 0 then return .nil
    if pos('timestamp.getBaseTime()',s) == 0 then return .nil
    if pos('timestamp.getUnixTime()',s) == 0 then return .nil
    if pos('timestamp.adjustTimeZone(',s) == 0 then return .nil
  end
  return .BifIR~new(name, def~line, def~minArg, def~maxArg, 'CLOCK_SUBSET', '', 'context->getTime; qualified subset, not full conversion', 'dynamic-context', 'activation')
::requires 'compiler/BifIR.cls'
