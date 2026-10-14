/* Independent PARSE template grammar rule.  Targets remain symbol references;
   position and delimiter patterns are data for the native parse executor.
   A template's dynamic delimiter values are captured before any target writes.
   Initial coverage: blank words, absolute and relative positions, quoted
   delimiters, and parenthesised variable delimiters. */
::class RxParseTemplateRules public
::method parse class
  use arg ctx, commaDelimited
  if arg(2, O) then commaDelimited = .false
  s = ctx~stream
  operations = .array~new
  targets = .array~new
  patterns = 0
  do while s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF' & (\commaDelimited | \s~is(','))
    t = s~peek
    select
      when t~kind == 'IDENT' then do
        name = s~next~text
        targets~append(name)
        operations~append('rx::ParseOp::target()')
      end
      when s~accept('.') then do
        targets~append('.')
        operations~append('rx::ParseOp::target()')
      end
      when (t~kind == 'INT' | t~kind == 'NUMBER') & verify(t~text, '0123456789') == 0 then do
        position = s~next~text
        if position~length > 18 then s~fail('PARSE position outside supported int64 range')
        operations~append('rx::ParseOp::absolute(' || position || ')')
        patterns = patterns + 1
      end
      when s~accept('=') then do
        if s~accept('(') then do
          expr = ctx~logicalExpr~parse(ctx)
          s~expect(')')
          operations~append('rx::ParseOp::absoluteValue(' || expr || ')')
        end
        else if self~integerPosition(s~peek) then do
          position = s~next~text
          if position~length > 18 then s~fail('PARSE position outside supported int64 range')
          operations~append('rx::ParseOp::absolute(' || position || ')')
        end
        else s~fail('PARSE = pattern requires an integer or (variable)')
        patterns = patterns + 1
      end
      when s~is('+') & s~lookAheadText(1) == '(' then do
        s~next; s~next
        expr = ctx~logicalExpr~parse(ctx)
        s~expect(')')
        operations~append('rx::ParseOp::relativeValue(' || expr || ', false)')
        patterns = patterns + 1
      end
      when s~is('-') & s~lookAheadText(1) == '(' then do
        s~next; s~next
        expr = ctx~logicalExpr~parse(ctx)
        s~expect(')')
        operations~append('rx::ParseOp::relativeValue(' || expr || ', true)')
        patterns = patterns + 1
      end
      when s~accept('+') then do
        if \self~integerPosition(s~peek) then s~fail('PARSE + pattern requires an integer position')
        offset = s~next~text
        if offset~length > 18 then s~fail('PARSE relative position outside supported int64 range')
        operations~append('rx::ParseOp::relative(' || offset || ')')
        patterns = patterns + 1
      end
      when s~accept('-') then do
        if \self~integerPosition(s~peek) then s~fail('PARSE - pattern requires an integer position')
        offset = s~next~text
        if offset~length > 18 then s~fail('PARSE relative position outside supported int64 range')
        operations~append('rx::ParseOp::relative(-' || offset || ')')
        patterns = patterns + 1
      end
      when t~kind == 'STRING' then do
        value = s~next~text
        if value == '' then s~fail('empty PARSE delimiter is unsupported')
        operations~append('rx::ParseOp::literal(' || .RxQuote~cpp(value) || ')')
        patterns = patterns + 1
      end
      when s~accept('(') then do
        expr = ctx~logicalExpr~parse(ctx)
        s~expect(')')
        operations~append('rx::ParseOp::literalValue(' || expr || ')')
        patterns = patterns + 1
      end
      otherwise s~fail('unsupported PARSE template component')
    end
  end
  /* No target at all (PULL alone, PARSE VAR x 'a'): valid; the source is still read. */
  if operations~items > 64 then s~fail('PARSE template exceeds qualified 64-element limit')
  initializer = ''
  do i = 1 to operations~items
    if i > 1 then initializer = initializer || ', '
    initializer = initializer || operations[i]
  end
  return .array~of(initializer, targets, patterns)
::method integerPosition class
  use arg token
  return (token~kind == 'INT' | token~kind == 'NUMBER') & verify(token~text, '0123456789') == 0
::requires 'rules/CompoundSymbols.cls'
::requires 'core/RxQuote.cls'
