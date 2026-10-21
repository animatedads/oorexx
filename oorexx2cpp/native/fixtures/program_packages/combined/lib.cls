::routine lookup public
  use arg name
  r = .context~package~findRoutine(name)
  if r == .nil then return 'findRoutine('name'): NOT FOUND'
  return 'findRoutine('name'):' r~call
::routine whereami public
  return 'package~name:' .context~package~name
::routine null.clause public
  return 'called'
