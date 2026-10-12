/* Native MutableBuffer fixture: compiled code builds buffers natively; they become interpreter objects when they leave. */
::class MBTest public
::method build
  b = .mutablebuffer~new('ab')
  b~append('c', 'd')~append('e')
  return b~string b~length
::method chain
  b = .MutableBuffer~new
  do i = 1 to 5
    b~append(i)
  end
  return b
::method mixed
  b = .mutablebuffer~new('hello')
  s1 = b~string
  b~insert('X', 2)
  b~append('!')
  return s1 b~string b~length b~isA(.MutableBuffer) b~class~id
::method identity
  use arg seen
  b = .mutablebuffer~new('id')
  seen~append(b)
  seen~append(b)
  b~append('+')
  return (seen[1] == seen[2]) seen[1]~string (seen[1] == b)
::method shout
  b = .mutablebuffer~new('say me')
  say b
  return 'x' || b
::method objArg
  b = .mutablebuffer~new
  b~append(.array~of(1, 2)~items)
  b~append(.mutablebuffer~new('in'))
  return b~string
::method size
  b = .mutablebuffer~new('q', 100)
  return b~string (b~getBufferSize >= 100)
