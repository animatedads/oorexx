/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_USERID public
::method bifName class
  return 'USERID'
::method argumentRange class
  return '0 0'
::method routeKind class
  return 'ISOLATED_REXX'
::method sourceLine class
  return 317
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_USERID(' || argumentsName || ',' || contextName || ')'
