/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_VALUE public
::method bifName class
  return 'VALUE'
::method argumentRange class
  return '1 3'
::method routeKind class
  return 'HOST_ACTIVATION'
::method sourceLine class
  return 380
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_VALUE(' || argumentsName || ',' || contextName || ')'
