/* Generated .cls are loaded after ooRexx-written source converter. */
if .RxBifFrameRule_ARG~bifName \== 'ARG' then raise syntax 40.900
if .RxBifFrameRule_ADDRESS~bifName \== 'ADDRESS' then raise syntax 40.900
if .RxBifFrameRule_ARG~routeKind \== 'COMPILED_FRAME_SCOPED' then raise syntax 40.900
if .RxBifFrameRule_ADDRESS~argumentRange \== '0 0' then raise syntax 40.900
if .RxBifFrameRule_ARG~emitCppExpression('scope','args') \== 'rxbif_frame_generated::BIF_ARG(scope, args)' then raise syntax 40.900
if .RxBifFrameRule_ADDRESS~emitCppExpression('scope') \== 'rxbif_frame_generated::BIF_ADDRESS(scope)' then raise syntax 40.900
say 'PASS generated ooRexx frame rules'

::requires 'Bif_ARG.cls'
::requires 'Bif_ADDRESS.cls'
