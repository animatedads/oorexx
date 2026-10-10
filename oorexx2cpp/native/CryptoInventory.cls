/* Safe, non-executing ooRexx source-directive inventory. This is an
   inventory, not a parser: report counts without claiming compilation. */
::class RxCryptoInventory public
::method analyze
  use arg source
  classes = 0; methods = 0; routines = 0; options = 0; requires = 0
  currentClass = ''
  report = 'line' || '09'x || 'directive' || '09'x || 'owner' || '09'x || 'declaration' || '0a'x
  offset = 1; lineNumber = 0
  do while offset <= source~length
    eol = source~pos('0a'x, offset)
    if eol = 0 then do
      line = source~substr(offset)
      offset = source~length + 1
    end
    else do
      line = source~substr(offset, eol-offset)
      offset = eol + 1
    end
    lineNumber += 1
    line = line~strip
    upper = line~upper
    if left(upper, 2) \= '::' then iterate
    kind = word(upper, 1)
    select
      when kind == '::CLASS' then do
        classes += 1
        currentClass = word(upper, 2)
      end
      when kind == '::METHOD' then methods += 1
      when kind == '::ROUTINE' then routines += 1
      when kind == '::OPTIONS' then options += 1
      when kind == '::REQUIRES' then requires += 1
      otherwise iterate
    end
    owner = currentClass
    if kind == '::ROUTINE' | kind == '::OPTIONS' | kind == '::REQUIRES' then owner = '-'
    report = report || lineNumber || '09'x || kind || '09'x || owner || '09'x || line || '0a'x
  end
  say 'classes:' classes 'methods:' methods 'routines:' routines 'options:' options 'requires:' requires
  return report
