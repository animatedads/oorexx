/* A constant is a getter on both class and instance. Preserve a native
   ::CONSTANT directive in the linked interpreter package so its exact class
   dispatch semantics remain under ooRexx's control. */
::class RxHybridConstantDirective public
::method parse
  use arg ctx
  s = ctx~stream
  s~expect('::'); s~expect('CONSTANT')
  if s~peek~kind \= 'IDENT' then s~fail('CONSTANT requires a simple name')
  name = s~next~text
  if pos('.', name) > 0 then s~fail('compound CONSTANT names are unsupported')
  value = ''
  token = s~peek
  select
    when token~kind == 'STRING' then do
      value = "'" || token~text~changeStr("'", "''") || "'"
      s~next
    end
    when token~kind == 'NUMBER' | token~kind == 'INT' | token~kind == 'IDENT' then do
      value = token~text
      s~next
    end
    otherwise nop
  end
  s~separator
  ctx~addConstant(name, value)
