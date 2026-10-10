/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_BITAND public
::method bifName class
  return 'BITAND'
::method argumentRange class
  return '1 3'
::method routeKind class
  return 'NATIVE_SUBSET'
::method sourceLine class
  return 327
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_BITAND(' || argumentsName || ',' || contextName || ')'
