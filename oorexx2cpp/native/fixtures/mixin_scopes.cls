::class Root public
::method init
  expose value
  use arg value
::method rootValue
  expose value
  return value
::method who
  return 'root'

::class Salt public mixinclass Root
::method saltSet
  expose value
  use arg value
  return value
::method saltValue
  expose value
  return value
::method who
  return 'salt'

::class Pepper mixinclass Root public
::method pepperSet
  expose value
  use arg value
  return value
::method pepperValue
  expose value
  return value
::method who
  return 'pepper'

::class Dish subclass Root public inherit Salt Pepper
::method dishSet
  expose value
  use arg value
  return value
::method dishValue
  expose value
  return value

::class Grand public subclass Dish
::method grandSet
  expose value
  use arg value
  return value
::method grandValue
  expose value
  return value
