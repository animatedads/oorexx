/* An ooRexx-owned verified inventory of BUILTIN macros, pinned to upstream.
   Input is read as data; Python is not involved in the conversion pipeline. */
::class BifBreadthCatalog public
::method init
  expose records order
  records = .directory~new
  order = .array~new
  path = 'catalog/bifs.tsv'
  if stream(path,'C','QUERY EXISTS') == '' then raise syntax 40.900 array ('BIF inventory missing:' path)
  do while lines(path) > 0
    row = linein(path)
    if left(row,5) == ('name' || '09'x) | strip(row) == '' then iterate
    parse var row name '09'x minArg '09'x maxArg '09'x mode '09'x evidence
    if records~hasIndex(name) then raise syntax 40.900 array ('Duplicate BIF name' name)
    if maxArg == '*' then maxArg = -2
    if \datatype(minArg,'W') | \datatype(maxArg,'W') then raise syntax 40.900 array ('Invalid BIF arity in inventory:' name)
    records[name] = minArg || ' ' || maxArg || ' ' || mode
    order~append(name)
  end
  call stream path,'C','CLOSE'
::method signature
  expose records
  use arg name
  if \records~hasIndex(name) then return ''
  return records[name]
::method names
  expose order
  return order
::method count
  expose order
  return order~items
