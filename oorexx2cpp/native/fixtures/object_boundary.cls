/* The same class runs interpreted or compiled. Its API is deliberately composed of
 * real ooRexx objects; converting arguments/results to strings would break it. */
::class BridgeProbe public
::method init
  expose stored
  stored = .nil
::method echo
  use arg item
  return item
::method stash
  expose stored
  use arg item
  stored = item
  return self
::method fetch
  expose stored
  return stored
::method make
  use arg value
  return .array~of(value)
::method replace
  use arg collection, value
  collection~put(value, 1)
  return collection
::method callback
  use arg receiver, value
  return receiver~echo(value)
::method bounce
  use arg receiver, value
  return receiver~bounce(self, value)
::method optional
  use strict arg item = 'default'
  return item
