/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_CHANGESTR public
::method bifName class
  return 'CHANGESTR'
::method argumentRange class
  return '3 4'
::method routeKind class
  return 'HOST_ACTIVATION'
::method sourceLine class
  return 499
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_CHANGESTR(' || argumentsName || ',' || contextName || ')'
