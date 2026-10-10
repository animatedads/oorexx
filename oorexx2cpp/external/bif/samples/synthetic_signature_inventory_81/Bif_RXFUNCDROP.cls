/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_RXFUNCDROP public
::method bifName class
  return 'RXFUNCDROP'
::method argumentRange class
  return '1 1'
::method routeKind class
  return 'HOST_ACTIVATION'
::method sourceLine class
  return 520
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_RXFUNCDROP(' || argumentsName || ',' || contextName || ')'
