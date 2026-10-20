::routine lookup public
  use arg name
  r = .context~package~findRoutine(name)
  if r == .nil then return 'findRoutine('name'): NOT FOUND'
  return 'findRoutine('name'):' r~call
::routine whereami public
  return 'package~name:' filespec('name', .context~package~name)
::routine null.clause public
  return 'called'
::routine hiddenRoutine
  return 'hidden routine'
::routine makeHidden public
  return .hidden~new
::class hidden
::method hello
  return 'hello from' filespec('name', self~class~package~name)
