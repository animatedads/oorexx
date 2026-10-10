/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_ERRORTEXT public
::method bifName class
  return 'ERRORTEXT'
::method argumentRange class
  return '1 1'
::method routeKind class
  return 'ISOLATED_REXX'
::method sourceLine class
  return 324
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_ERRORTEXT(' || argumentsName || ',' || contextName || ')'
