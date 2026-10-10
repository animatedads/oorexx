/* Source-derived rule; breadth routing does not assert native equivalence. */
::class RxBifBreadthRule_POS public
::method bifName class
  return 'POS'
::method argumentRange class
  return '2 4'
::method routeKind class
  return 'HOST_ACTIVATION'
::method sourceLine class
  return 51
::method emitCppExpression class
  use arg argumentsName, contextName
  if argumentsName == '' | contextName == '' then raise syntax 40.900 array ('C++ names required')
  return 'rxbif_breadth_generated::BIF_POS(' || argumentsName || ',' || contextName || ')'
