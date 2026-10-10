/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_TRANSLATE public
::method bifName class
  return 'TRANSLATE'
::method argumentRange class
  return '1 6'
::method routeKind class
  return 'ISOLATED_REXX'
::method sourceLine class
  return 268
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_TRANSLATE(' || argumentsName || ',' || contextName || ')'
