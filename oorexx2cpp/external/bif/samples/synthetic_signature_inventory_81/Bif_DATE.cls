/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_DATE public
::method bifName class
  return 'DATE'
::method argumentRange class
  return '0 5'
::method routeKind class
  return 'HOST_ACTIVATION'
::method sourceLine class
  return 338
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_DATE(' || argumentsName || ',' || contextName || ')'
