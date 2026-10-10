if .RxBifControlRule_SOURCELINE~bifName \== 'SOURCELINE' then raise syntax 40.900
if .RxBifControlRule_TRACE~bifName \== 'TRACE' then raise syntax 40.900
if .RxBifControlRule_CONDITION~bifName \== 'CONDITION' then raise syntax 40.900
if .RxBifControlRule_TRACE~argumentRange \== '0 1' then raise syntax 40.900
if .RxBifControlRule_CONDITION~routeKind \== 'ORIGINAL_CONTROL_ACTIVATION' then raise syntax 40.900
if .RxBifControlRule_SOURCELINE~emitCppExpression('frame','args') \== 'rxbif_control_generated::BIF_SOURCELINE(frame, args)' then raise syntax 40.900
say 'PASS ooRexx-generated SOURCELINE/TRACE/CONDITION control rules'
::requires 'Bif_SOURCELINE.cls'
::requires 'Bif_TRACE.cls'
::requires 'Bif_CONDITION.cls'
