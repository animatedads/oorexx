::class Parcel public
::method init
::attribute thing
::method alias
  forward message 'THING'
::method alias2
  return self~thing
::method put
  use arg newValue
  return self~alias
