/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_ENDLOCAL public
::method bifName class
  return 'ENDLOCAL'
::method argumentRange class
  return '0 0'
::method routeKind class
  return 'HOST_ACTIVATION'
::method sourceLine class
  return 548
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_ENDLOCAL(' || argumentsName || ',' || contextName || ')'
