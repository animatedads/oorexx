/* Class visibility in a compiled library: PUBLIC classes are seen by the requiring program; PRIVATE and
   default classes only inside this package, exactly as interpreted. */
::class Pub public
::method init
::method run
  h = .Helper~new
  d = .Hidden~new
  return h~name d~name
::class Helper private
::method init
::method name
  return 'helper'
::class Hidden
::method init
::method name
  return 'hidden'
