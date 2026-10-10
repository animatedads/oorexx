/* ooRexx converter authority. Verifies ORIGINAL interpreter C++ BUILTIN
   bodies before emitting frame-bound C++ wrappers for ARG and ADDRESS.
   An unchanged name/arity alone is insufficient to certify semantics. */
::class BifFrameRouteRule public
::method convert
  use arg definition
  n = definition~name
  source = definition~joined
  select
    when n == 'ADDRESS' then do
      if definition~minArg \= 0 | definition~maxArg \= 0 then return .false
      if pos('check_args(ADDRESS);',source) == 0 then return .false
      if pos('return context->getAddress();',source) == 0 then return .false
      if self~count(source,'return ') \= 1 then return .false
      return .true
    end
    when n == 'ARG' then do
      if definition~minArg \= 0 | definition~maxArg \= 2 then return .false
      if pos('fix_args(ARG);',source) == 0 then return .false
      if pos('context->getMethodArgumentList()',source) == 0 then return .false
      if pos('context->getMethodArgumentCount()',source) == 0 then return .false
      if pos('return new_integer(size);',source) == 0 then return .false
      if pos("case 'E':",source) == 0 | pos("case 'O':",source) == 0 then return .false
      if pos("case 'N':",source) == 0 | pos("case 'A':",source) == 0 then return .false
      if pos('arglist[position - 1]',source) == 0 then return .false
      return .true
    end
    otherwise return .false
  end
::method count
  use arg hay,needle
  p = 1
  tally = 0
  do forever
    p = pos(needle,hay,p)
    if p == 0 then leave
    tally += 1
    p += length(needle)
  end
  return tally
