/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_SIGN public
::method bifName class
  return 'SIGN'
::method argumentRange class
  return '1 1'
::method routeKind class
  return 'ISOLATED_REXX'
::method sourceLine class
  return 394
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_SIGN(' || argumentsName || ',' || contextName || ')'
