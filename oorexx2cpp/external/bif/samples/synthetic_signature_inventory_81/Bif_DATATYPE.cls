/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_DATATYPE public
::method bifName class
  return 'DATATYPE'
::method argumentRange class
  return '1 2'
::method routeKind class
  return 'ISOLATED_REXX'
::method sourceLine class
  return 282
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_DATATYPE(' || argumentsName || ',' || contextName || ')'
