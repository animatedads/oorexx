/* Conversion authority: ooRexx rule reads original C++ BUILTIN definitions.
   Only source-verified zero-argument activation API substitutions are eligible.
   This emits inline calls to a BORROWED host CallScope; never stores the scope. */
::class BifLiveCallRule public
::method convert
  use arg def
  name = def~name
  if wordpos(name,'DIGITS FUZZ FORM FORMAT') == 0 then return .nil
  if name == 'FORMAT' then do
    if def~minArg \= 1 | def~maxArg \= 5 then return .nil
    src = def~joined
    if pos('fix_args(FORMAT);',src) == 0 then return .nil
    if pos('return number->format(before, after, expp, expt);',src) == 0 then return .nil
    normalized = space(src,1)
    if self~count(src,';') \= 14 | self~count(src,'{') \= 1 | self~count(src,'}') \= 1 then return .nil
    argnames = 'number before after expp expt'
    do i = 1 to 5
      arg = word(argnames,i)
      if pos('FORMAT_' || arg || ' = ' || i || ';',normalized) == 0 then return .nil
    end
    if pos('RexxString *number = required_string(FORMAT, number);',src) == 0 then return .nil
    do i = 2 to 5
      arg = word(argnames,i)
      if pos('RexxInteger *' || arg || ' = optional_integer(FORMAT, ' || arg || ');',src) == 0 then return .nil
    end
    if self~count(src,'return ') \= 1 then return .nil
    return .true
  end
  if def~minArg \= 0 | def~maxArg \= 0 then return .nil
  src = def~joined
  if pos('check_args(' || name || ');',src) == 0 then return .nil
  select
    when name == 'DIGITS' then signature = 'return new_integer(context->digits());'
    when name == 'FUZZ' then signature = 'return new_integer(context->fuzz());'
    when name == 'FORM' then signature = 'return context->form() == Numerics::FORM_SCIENTIFIC ? GlobalNames::SCIENTIFIC : GlobalNames::ENGINEERING;'
    otherwise return .nil
  end
  if pos(signature,src) == 0 then return .nil
  /* No additional returns/branches beyond the single upstream invocation. */
  if self~count(src,'return ') \= 1 then return .nil
  return .true
::method count
  use arg hay,needle
  tally = 0
  from = 1
  do forever
    p = pos(needle,hay,from)
    if p == 0 then leave
    tally += 1
    from = p + length(needle)
  end
  return tally
