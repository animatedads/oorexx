if .RxBifLiveRule_DIGITS~bifName \== 'DIGITS' then exit 1
if .RxBifLiveRule_FUZZ~routeKind \== 'LIVE_CALL_SCOPED' then exit 2
if .RxBifLiveRule_FORM~argumentRange \== '0 0' then exit 3
if .RxBifLiveRule_FORM~emitCppExpression('scope') \== 'rxbif_live_generated::BIF_FORM(scope)' then exit 4
if .RxBifLiveRule_FORMAT~argumentRange \== '1 5' then exit 5
if .RxBifLiveRule_FORMAT~emitCppExpression('scope','args') \== 'rxbif_live_generated::BIF_FORMAT(scope, args)' then exit 6
say 'PASS live rule classes'
::requires 'live/generated/Bif_DIGITS.cls'
::requires 'live/generated/Bif_FUZZ.cls'
::requires 'live/generated/Bif_FORM.cls'
::requires 'Bif_FORMAT.cls'
