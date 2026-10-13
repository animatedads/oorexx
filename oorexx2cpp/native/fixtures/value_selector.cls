/* VALUE with a selector in compiled code: ENVIRONMENT, '' (.environment), errors; the local pool stays compiled. */
::class ValueSelector public
::method init
::method run
  x = 'local'
  say 'local' value('X')
  say 'env set' (value('RX2CPP_VALUE_TEST', , 'ENVIRONMENT') == 'abc')
  say 'env missing' '['value('RX2CPP_VALUE_MISSING', , 'ENVIRONMENT')']'
  old = value('RX2CPP_VALUE_TEST', 'xyz', 'ENVIRONMENT')
  say 'env exchanged' old value('RX2CPP_VALUE_TEST', , 'ENVIRONMENT')
  .environment~rx2cppValueProbe = 'probe'
  say 'dot environment' value('RX2CPP.VALUE.PROBE', , '') value('RX2CPPVALUEPROBE', , '')
  old = value('RX2CPPVALUEPROBE', 'new', '')
  say 'dot exchanged' old .environment~rx2cppValueProbe
  say 'local again' x value('X')
  signal on syntax
  say value('X', , 'NOSUCHPOOL')
  say 'not reached'
  return
syntax:
  c = condition('O')
  say 'syntax' c~code c~message
