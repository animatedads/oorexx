/* BIF catalogue is loaded at compiler invocation time from the separately
   delivered BIF rules package.  Compiler never owns BIF implementations.
   Malformed/duplicate entries fail before C++ emission. */
::class RxBifCatalog public
::method init
  expose specs size
  specs = .directory~new
  size = 0
  root = value('RX2CPP_BIF_ROOT',,'ENVIRONMENT')
  if root == '' then raise syntax 40.900 array ('rx2cpp: RX2CPP_BIF_ROOT must name an unpacked BIF release')
  path = root || '/catalog/bifs.tsv'
  if stream(path,'C','QUERY EXISTS') == '' then raise syntax 40.900 array ('rx2cpp: BIF manifest is absent: ' || path)
  tab = '09'x
  do while lines(path) > 0
    record = linein(path)
    if record == '' then iterate
    parse var record n (tab) minimum (tab) maximum (tab) mode (tab) evidence
    if n == 'name' then iterate
    if n == '' | verify(n,'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_') \= 0 then -
      raise syntax 40.900 array ('rx2cpp: invalid BIF name in catalog')
    if specs~hasIndex(n) then raise syntax 40.900 array ('rx2cpp: duplicate BIF name ' || n)
    if datatype(minimum,'W') == 0 then raise syntax 40.900 array ('rx2cpp: invalid minimum arity for ' || n)
    if maximum \= '*' & datatype(maximum,'W') == 0 then -
      raise syntax 40.900 array ('rx2cpp: invalid maximum arity for ' || n)
    if maximum \= '*' & maximum < minimum then -
      raise syntax 40.900 array ('rx2cpp: BIF arity reversal for ' || n)
    if wordpos(mode,'NATIVE_SUBSET RX2CPP_BASE_SUBSET ISOLATED_REXX HOST_ACTIVATION') == 0 then -
      raise syntax 40.900 array ('rx2cpp: invalid BIF route for ' || n)
    specs[n] = minimum maximum mode
    size += 1
  end
  call stream path,'C','CLOSE'
  if size \= 81 then raise syntax 40.900 array ('rx2cpp: expected all 81 BIF registrations, got ' || size)
::method has
  expose specs
  use arg name
  return specs~hasIndex(name)
::method signature
  expose specs
  use arg name
  if specs~hasIndex(name) then return specs[name]
  return ''
::method count
  expose size
  return size
