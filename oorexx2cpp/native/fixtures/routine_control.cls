/* Differential fixture: method and routine activations share IF and DO WHILE. */
::class ControlHost public
::method init
  expose marker
  marker = 'ready'
::method reduce
  use arg a, b
  if a < 0 then a = a + b
  do while a > b
    a = a - b
  end
  return a

::routine RX_CONTROL PUBLIC
  numeric digits 20
  use arg a, b
  if a < 0 then a = a + b
  else if a == 0 then a = b
  if a == 1 then return 99
  do while a > b
    if a > (b * 2) then a = a - b
    else a = a - 1
  end
  return a

::routine RX_NESTED PUBLIC
  use arg n
  x = 0
  if n > 0 then do while n > 1
    if n > 3 then x = x + 2
    else x = x + 1
    n = n - 1
  end
  else x = 17
  return x
