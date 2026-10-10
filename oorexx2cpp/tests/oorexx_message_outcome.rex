obj = .Thing~new
result = 'stale'
obj~nothing
say 'no-result' result
obj~~nothing
say 'cascade-equals' (result == obj)
obj~value
say 'returned' result
x = obj~value
say 'expression' x result
obj~'='(obj)
say 'object-quoted-equal' result
obj~nothing
say 'cleared' result
signal on syntax name noReturnError
x = obj~nothing
say 'unexpected'
exit 3
noReturnError:
  say 'expression-no-result ERROR'
exit 0
::class Thing
::method nothing
  return
::method value
  return 'word'
