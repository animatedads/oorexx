/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_LENGTH public
::method bifName class
  return 'LENGTH'
::method argumentRange class
  return '1 1'
::method routeKind class
  return 'RX2CPP_BASE_SUBSET'
::method sourceLine class
  return 261
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_LENGTH(' || argumentsName || ',' || contextName || ')'
