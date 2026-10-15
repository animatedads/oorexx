/* The string value of an interpreter object of a class that is not built in (RexxInternalObject::requestString):
   REQUEST('STRING') first (a class may override it), then STRING with NOSTRING; a built-in class's object: its
   primitive string value (an Array: STRING, with NOSTRING). */
::class Requests public
::method run
  use arg viaRequest, viaString, viaMake
  say 'x' viaRequest
  say 'x' viaMake
  signal on nostring
  say 'x' viaString
  return 'not trapped'
nostring:
  say 'NOSTRING' condition('D')
  signal on nostring name arrayNostring
  say 'x' .array~of(1, 2)
  return 'no'
arrayNostring:
  return 'array NOSTRING' condition('D')
