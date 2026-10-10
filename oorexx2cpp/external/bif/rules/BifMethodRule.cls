/* Converts canonical upstream wrapper BIF: arg macros -> forwarding method.
   Stores the actual delegated C++ method in IR. Rejects other structures. */
::class BifMethodRule public
::method accept
  use arg def
  return def~name \= 'DATE' & def~name \= 'TIME'
::method convert
  use arg def
  name = def~name
  body = def~joined
  if def~minArg < 0 | def~maxArg < 0 | def~minArg > def~maxArg then return .nil
  if pos('fix_args(' || name || ')',body) == 0 then return .nil
  /* a wrapper has ONE return of the form receiver->method(arguments); */
  /* Convert the upstream string, integer, and pad stack binding macros
     into stable typed argument descriptors in the intermediary. */
  argMeta = ''
  do v over def~lines
    t = strip(v)
    equal = pos(' = ', t)
    if equal == 0 then iterate
    rhs = strip(substr(t, equal + 3))
    opening = pos('(',rhs)
    if opening == 0 then iterate
    macro = substr(rhs,1,opening-1)
    if left(macro,9) \== 'required_' & left(macro,9) \== 'optional_' then iterate
    closing = pos(')',rhs,opening+1)
    if closing == 0 then return .nil
    params = substr(rhs,opening+1,closing-opening-1)
    parse var params unused ',' field
    if strip(unused) \== name then return .nil
    field = strip(field)
    if verify(field,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_') \= 0 then return .nil
    if argMeta \== '' then argMeta = argMeta || ','
    argMeta = argMeta || field || ':' || macro
  end
  count = 0
  /* Whitelist grammar: no arbitrary statements may hide alongside a return. */
  do v over def~lines
    t = strip(v)
    if t == '' | t == '{' | t == '}' then iterate
    if left(t,2) == '//' then iterate
    if left(t,8) == 'BUILTIN(' then iterate
    if left(t,13) == 'const size_t ' then iterate
    if left(t,9) == 'fix_args(' then iterate
    if left(t,9) == 'check_args(' then iterate
    if left(t,11) == 'RexxString ' then iterate
    if left(t,12) == 'RexxInteger ' then iterate
    if left(t,7) == 'return ' then iterate
    return .nil
  end
  method = ''
  callShape = ''
  do v over def~lines
    t = strip(v)
    if left(t,7) == 'return ' then do
      count += 1
      expr = strip(substr(t,8))
      if right(expr,1) \== ';' then return .nil
      expr = strip(substr(expr,1,length(expr)-1))
      e = pos('->',expr)
      opening = pos('(',expr,e+2)
      closing = lastpos(')',expr)
      if e == 0 | opening == 0 | closing \= length(expr) then return .nil
      receiver = strip(substr(expr,1,e-1))
      method = strip(substr(expr,e+2,opening-e-2))
      args = strip(substr(expr,opening+1,closing-opening-1))
      if verify(receiver,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_') \= 0 then return .nil
      if verify(method,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_') \= 0 then return .nil
      if verify(args,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_, ') \= 0 then return .nil
      if \.BifCallShapeRule~matches(name,receiver,args) then return .nil
      callShape = receiver || '->' || method || '(' || changestr(' ',args,'') || ')'
    end
  end
  if count \= 1 then return .nil
  /* An upstream return method, receiver and argument sequence are verified
     against qualified native behavior before this IR can be emitted. */
  return .BifIR~new(name, def~line, def~minArg, def~maxArg, 'METHOD', method, ,
      'return ' || callShape, argMeta, callShape)
::requires 'compiler/BifIR.cls'
::requires 'rules/BifCallShapeRule.cls'
