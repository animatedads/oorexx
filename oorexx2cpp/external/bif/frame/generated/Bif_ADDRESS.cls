/* Generated from the upstream C++ BUILTIN by ooRexx. */
::class RxBifFrameRule_ADDRESS public
::method bifName class
  return 'ADDRESS'
::method routeKind class
  return 'COMPILED_FRAME_SCOPED'
::method argumentRange class
  return '0 0'
::method sourceLine class
  return 4
::method emitCppExpression class
  use arg scopeName
  if scopeName == '' then raise syntax 40.900 array ('Original compiled frame required')
  return 'rxbif_frame_generated::BIF_ADDRESS(' || scopeName || ')'
