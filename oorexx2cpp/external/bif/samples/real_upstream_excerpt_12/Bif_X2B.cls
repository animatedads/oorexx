/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_X2B public
::method bifName class
  return 'X2B'
::method argumentRange class
  return '1 1'
::method routeKind class
  return 'NATIVE_SUBSET'
::method sourceLine class
  return 391
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_X2B(' || argumentsName || ',' || contextName || ')'
