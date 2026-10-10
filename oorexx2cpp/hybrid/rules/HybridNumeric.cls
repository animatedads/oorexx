/* NUMERIC instruction updates the current Rexx activation's context.
   Only integer literals and the two FORM keywords are compiled; expressions
   must fail closed. In particular, do not confuse NUMERIC with ::OPTIONS. */
::class RxHybridNumeric public
::method accepts
  use arg ctx
  return ctx~stream~is('NUMERIC')
::method emit
  use arg ctx
  s = ctx~stream
  s~expect('NUMERIC')
  operation = s~next~text
  select
    when operation == 'DIGITS' | operation == 'FUZZ' then do
      value = s~next
      if value~kind \= 'NUMBER' | verify(value~text, '0123456789') > 0 | ,
        length(value~text) > 6 then s~fail('NUMERIC ' || operation || ' requires a bounded unsigned literal')
      n = value~text + 0
      if (operation == 'DIGITS' & (n < 1 | n > 100000)) | ,
         (operation == 'FUZZ' & (n < 0 | n > 99999)) then
        s~fail('NUMERIC ' || operation || ' outside compiled range')
      if operation == 'DIGITS' then do
        ctx~current~addNumericInstruction('if (vars.numeric.fuzz >= ' || n || ') throw std::runtime_error("NUMERIC DIGITS must exceed FUZZ");')
        ctx~current~addNumericInstruction('vars.numeric.digits = ' || n || ';')
      end
      else do
        ctx~current~addNumericInstruction('if (' || n || ' >= vars.numeric.digits) throw std::runtime_error("NUMERIC FUZZ must be less than DIGITS");')
        ctx~current~addNumericInstruction('vars.numeric.fuzz = ' || n || ';')
      end
    end
    when operation == 'FORM' then do
      form = s~next~text
      if form \= 'SCIENTIFIC' & form \= 'ENGINEERING' then
        s~fail('NUMERIC FORM requires SCIENTIFIC or ENGINEERING')
      setting = 'false'
      if form == 'ENGINEERING' then setting = 'true'
      ctx~current~addNumericInstruction('vars.numeric.engineering = ' || setting || ';')
    end
    otherwise s~fail('unsupported NUMERIC instruction ' || operation)
  end
  s~separator
