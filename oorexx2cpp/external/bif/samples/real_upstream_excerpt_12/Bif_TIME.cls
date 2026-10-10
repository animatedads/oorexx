/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_TIME public
::method bifName class
  return 'TIME'
::method argumentRange class
  return '0 3'
::method routeKind class
  return 'NATIVE_SUBSET'
::method sourceLine class
  return 48
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_TIME(' || argumentsName || ',' || contextName || ')'
