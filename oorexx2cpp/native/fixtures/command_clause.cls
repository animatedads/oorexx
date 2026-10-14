::class CM public
::method init
::method run
  'echo literal command'
  say 'rc' rc
  ('exit' 4)
  say 'rc' rc
  signal on syntax
  date('*')
  return 'no'
syntax:
  return 'syntax' condition('O')~code
