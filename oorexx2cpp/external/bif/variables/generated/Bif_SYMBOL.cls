/* Generated from verified upstream C++ BUILTIN by ooRexx. */
::class RxBifVariableRule_SYMBOL public
::method bifName class
  return 'SYMBOL'
::method routeKind class
  return 'COMPILED_VARIABLE_SCOPE'
::method argumentRange class
  return '1 1'
::method sourceLine class
  return 5
::method emitCppExpression class
  use arg scopeName, arguments
  if scopeName == '' | arguments == '' then raise syntax 40.900 array ('Caller scope and argument expression required')
  return 'rxbif_variables_generated::BIF_SYMBOL(' || scopeName || ', ' || arguments || ')'
