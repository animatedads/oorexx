/* Prologue may include ::class as text, not a directive */
phrase = "::class Fake"
say 'DO NOT EXECUTE PROLOGUE'
::options noprolog
::class Sample public
::method ping
  return "hello"
::method secret private
  return "classified"
::method utility private class
  return "class-side"
::routine internal private
  return 9
::routine exposed public
  return 8
