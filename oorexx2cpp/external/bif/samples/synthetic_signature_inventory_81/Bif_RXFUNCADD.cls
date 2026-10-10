/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_RXFUNCADD public
::method bifName class
  return 'RXFUNCADD'
::method argumentRange class
  return '2 3'
::method routeKind class
  return 'HOST_ACTIVATION'
::method sourceLine class
  return 513
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_RXFUNCADD(' || argumentsName || ',' || contextName || ')'
