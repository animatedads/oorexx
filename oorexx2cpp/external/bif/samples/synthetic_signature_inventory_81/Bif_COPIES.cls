/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_COPIES public
::method bifName class
  return 'COPIES'
::method argumentRange class
  return '2 2'
::method routeKind class
  return 'HOST_ACTIVATION'
::method sourceLine class
  return 142
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_COPIES(' || argumentsName || ',' || contextName || ')'
