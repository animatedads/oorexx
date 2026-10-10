/* Generated from the upstream C++ BUILTIN by ooRexx. */
::class RxBifFrameRule_ARG public
::method bifName class
  return 'ARG'
::method routeKind class
  return 'COMPILED_FRAME_SCOPED'
::method argumentRange class
  return '0 2'
::method sourceLine class
  return 12
::method emitCppExpression class
  use arg scopeName, arguments
  if scopeName == '' then raise syntax 40.900 array ('Original compiled frame required')
  if arguments == '' then raise syntax 40.900 array ('BIF ARG requires call arguments')
  return 'rxbif_frame_generated::BIF_ARG(' || scopeName || ', ' || arguments || ')'
