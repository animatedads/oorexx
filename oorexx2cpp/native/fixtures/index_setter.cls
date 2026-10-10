/* Indexed object protocol: []=(value,index), [](index).
   The native package must preserve ooRexx's argument order and instance scope. */
::class IndexedCell public
::method init
  expose savedIndex savedValue
  savedIndex = 0
  savedValue = 0
::method '[]='
  expose savedIndex savedValue
  use arg newValue, index
  savedIndex = index
  savedValue = newValue
  return newValue
::method '[]'
  expose savedIndex savedValue
  use arg index
  return savedValue + index
::method index
  expose savedIndex
  return savedIndex
::method value
  expose savedValue
  return savedValue
::method combine
  use arg value, key
  return value * 100 + key
/* Inherited indexed setters must continue to use their defining scope. */
::class IndexedChild public subclass IndexedCell
::method identify
  return self~index + self~value
