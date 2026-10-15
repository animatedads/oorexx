/* A constant is a getter on both class and instance. Preserve a native
   ::CONSTANT directive in the linked interpreter package so its exact class
   dispatch semantics remain under ooRexx's control.

   ::CONSTANT name [value], as LanguageParser::constantDirective reads it: the name a symbol or a literal string (the
   method is its uppercase form; with no value the constant is the name as written); the value a literal, a symbol,
   a signed number or an expression in parentheses. The directive goes to the declaration package as written (rebuilt
   from its tokens, which keeps abuttal: the interpreter validates and evaluates it). */
::class RxHybridConstantDirective public
::method parse
  use arg ctx
  s = ctx~stream
  s~expect('::'); s~expect('CONSTANT')
  token = s~peek
  if token~kind \= 'IDENT' & token~kind \= 'STRING' then s~fail('CONSTANT requires a symbol or string name')
  s~next
  if token~kind == 'STRING' then nameText = self~literal(token~text)
  else nameText = token~text
  name = token~text~upper
  value = ''
  previous = .nil
  do while s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF'
    t = s~next
    if previous \== .nil then
      if \(t~line == previous~endLine & t~col == previous~endCol) then value = value || ' '
    select
      when t~kind == 'STRING' then value = value || self~literal(t~text)
      when t~kind == 'DOTIDENT' then value = value || '.' || t~text
      otherwise value = value || t~text
    end
    previous = t
  end
  s~separator
  ctx~addConstant(name, value, nameText)
/* a literal string for the declaration source: as is when printable, else in hex */
::method literal private
  use arg text
  printable = xrange('20'x, '7e'x)
  if verify(text, printable) = 0 then return "'" || text~changeStr("'", "''") || "'"
  return "'" || text~c2x || "'x"
