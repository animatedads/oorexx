::class Root public
::method init
  expose value
  use arg start
  value = start
::method rootValue
  expose value
  return value
::method rootSet
  expose value
  use arg n
  value = n
  return value
::method shared
  return 'root'

::class Branch public subclass Root
::method branchValue
  expose value
  return value
::method branchSet
  expose value
  use arg n
  value = n
  return value
::method shared
  return 'branch'

::class Leaf public subclass Branch
::method leafValue
  expose value
  return value
::method leafSet
  expose value
  use arg n
  value = n
  return value
::method shared
  return 'leaf'
