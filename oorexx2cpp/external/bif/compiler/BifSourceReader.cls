/* Native ooRexx scanner. Source of truth is upstream BUILTIN(NAME) macro C++.
   Retains the original BIF body, checks balanced braces with C/C++ comment
   and quote awareness, and extracts actual _Min and _Max declarations. */
::class BifSourceReader public
::method scan
  use arg pathname
  source = .array~new
  do while lines(pathname) > 0
    source~append(linein(pathname))
  end
  call stream pathname, 'C', 'CLOSE'
  masked = self~maskSource(source)
  parsed = .array~new
  index = 1
  do while index <= source~items
    s = strip(masked[index])
    if left(s, 8) \== 'BUILTIN(' then do
      index += 1
      iterate
    end
    terminator = pos(')', s, 9)
    if terminator == 0 then raise syntax 40.900 array ('Malformed BUILTIN macro, line' index)
    name = substr(s, 9, terminator - 9)
    if name == '' | verify(name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_') \= 0 then
       raise syntax 40.900 array ('Invalid BUILTIN name, line' index)
    start = index
    body = .array~new
    depth = 0
    started = .false
    state = 'CODE'
    do forever
      if index > source~items then raise syntax 40.900 array ('Unterminated upstream BIF' name)
      body~append(source[index])
      /* Analyze braces in the comment/string-masked source, not raw text. */
      text = masked[index]
      do p = 1 to length(text)
        c = substr(text,p,1)
        if c == '{' then do; depth += 1; started = .true; end
        if c == '}' then do
          depth -= 1
          if depth < 0 then raise syntax 40.900 array ('Unexpected C++ closing brace for' name)
        end
      end
      if started & depth == 0 then leave
      index += 1
    end
    /* RIGHT and some other functions declare arities BEFORE the macro. */
    back = max(1, start - 18)
    arityLines = .array~new
    do j = back to start - 1
      arityLines~append(masked[j])
    end
    do j = start to index
      arityLines~append(masked[j])
    end
    minArg = self~declaration(arityLines,name,'Min')
    maxArg = self~declaration(arityLines,name,'Max')
    parsed~append(.BifDefinition~new(name, start, body, minArg, maxArg))
    index += 1
  end
  return parsed
/* Return same-length lexical code lines; comments and quoted text are spaces.
   Keeps C++ comment state across lines. This prevents false BUILTIN/arity hits. */
::method maskSource
  use arg source
  masked = .array~new
  state = 'CODE'
  do line over source
    output = ''
    p = 1
    do while p <= length(line)
      c = substr(line,p,1)
      nxt = ''
      if p < length(line) then nxt = substr(line,p+1,1)
      select
        when state == 'BLOCK' then do
          if c == '*' & nxt == '/' then do
            output ||= '  '
            p += 2
            state = 'CODE'
            iterate
          end
          output ||= ' '
        end
        when state == 'DQ' | state == 'SQ' then do
          output ||= ' '
          if c == '\' then do
            if p < length(line) then do
              output ||= ' '
              p += 1
            end
          end
          else if (state == 'DQ' & c == '"') | (state == 'SQ' & c == "'") then state = 'CODE'
        end
        otherwise do
          if c == '/' & nxt == '/' then do
            output ||= copies(' ', length(line) - p + 1)
            leave
          end
          if c == '/' & nxt == '*' then do
            output ||= '  '
            p += 2
            state = 'BLOCK'
            iterate
          end
          if c == '"' then do
            output ||= ' '
            state = 'DQ'
          end
          else if c == "'" then do
            output ||= ' '
            state = 'SQ'
          end
          else output ||= c
        end
      end
      p += 1
    end
    masked~append(output)
  end
  return masked
::method declaration
  use arg source, name, field
  key = name || '_' || field
  found = ''
  do line over source
    /* guard against e.g. ANAME_Min and commented definitions */
    trimmed = strip(line)
    if left(trimmed,13) == '// ' then iterate
    if pos('const size_t ',trimmed) \= 1 then iterate
    p = pos(key, trimmed)
    if p == 0 then iterate
    before = strip(substr(trimmed,1,p - 1))
    if before \== 'const size_t' then iterate
    after = strip(substr(trimmed,p + length(key)))
    if left(after,1) \== '=' then iterate
    parse var after '=' number ';' .
    number = strip(number)
    if datatype(number,'W') then found = number
    else if number == 'argcount' & field == 'Max' & ,
         wordpos(name,'MAX MIN XRANGE') > 0 then found = -2
    else return -1   /* unknown dynamic source signature */
  end
  if found == '' then return -1
  return found + 0
::requires 'compiler/BifDefinition.cls'
