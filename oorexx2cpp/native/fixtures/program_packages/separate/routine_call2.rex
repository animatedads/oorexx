signal on syntax
say .runner~new~run('BAD')
exit
syntax:
  c = condition('o')
  say c~code c~message
  say .runner~new~run('GOOD')
::requires 'rlib.cls'
