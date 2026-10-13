/* BIF name/arity resolver. Native implementations belong to the independent
   BIF package; RX2CPP_BIF_ROOT selects its 81-name catalogue dynamically.
   Without the add-on, preserve the original ABS/LENGTH bootstrap subset. */
::class RxBuiltinRules public
::method catalogue class
  expose cache
  if var('CACHE') == 0 then do
    cache = .nil
    root = value('RX2CPP_BIF_ROOT',,'ENVIRONMENT')
    if root \= '' then cache = .RxBifCatalog~new
  end
  return cache
::method externalEnabled class
  return self~catalogue \== .nil
::method isBuiltinName class
  use arg name
  catalog = self~catalogue
  if catalog == .nil then return name == 'ABS' | name == 'LENGTH'
  return catalog~signature(name) \= ''
/* True when COUNT arguments are within the catalogue's arity for NAME (false for an unknown name). */
::method arityOk class
  use arg name, count
  catalog = self~catalogue
  if catalog == .nil then return (name == 'ABS' | name == 'LENGTH') & count == 1
  signature = catalog~signature(name)
  if signature == '' then return .false
  return count >= word(signature, 1) & (word(signature, 2) == '*' | count <= word(signature, 2))
::method validate class
  use arg stream,name,count
  catalog = self~catalogue
  if catalog == .nil then do
    if name \= 'ABS' & name \= 'LENGTH' then stream~fail('unimplemented built-in or external routine ' || name)
    if count \= 1 then stream~fail(name || ' requires exactly 1 argument')
    return
  end
  signature = catalog~signature(name)
  if signature == '' then stream~fail('unimplemented built-in or external routine ' || name)
  minimum = word(signature,1)
  maximum = word(signature,2)
  if count < minimum | (maximum \= '*' & count > maximum) then -
    stream~fail(name || ' requires ' || minimum || ' to ' || maximum || ' arguments')
::requires 'rules/RxBifCatalog.cls'
