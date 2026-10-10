/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_DIGITS public
::method bifName class
  return 'DIGITS'
::method argumentRange class
  return '0 0'
::method routeKind class
  return 'HOST_ACTIVATION'
::method sourceLine class
  return 296
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_DIGITS(' || argumentsName || ',' || contextName || ')'
