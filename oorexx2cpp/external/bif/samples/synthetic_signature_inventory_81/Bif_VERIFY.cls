/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_VERIFY public
::method bifName class
  return 'VERIFY'
::method argumentRange class
  return '2 5'
::method routeKind class
  return 'ISOLATED_REXX'
::method sourceLine class
  return 275
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_VERIFY(' || argumentsName || ',' || contextName || ')'
