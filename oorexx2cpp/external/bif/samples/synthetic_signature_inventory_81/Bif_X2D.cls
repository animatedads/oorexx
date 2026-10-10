/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_X2D public
::method bifName class
  return 'X2D'
::method argumentRange class
  return '1 2'
::method routeKind class
  return 'ISOLATED_REXX'
::method sourceLine class
  return 233
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_X2D(' || argumentsName || ',' || contextName || ')'
