/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_WORDS public
::method bifName class
  return 'WORDS'
::method argumentRange class
  return '1 1'
::method routeKind class
  return 'HOST_ACTIVATION'
::method sourceLine class
  return 156
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_WORDS(' || argumentsName || ',' || contextName || ')'
