/* Load source-generated rule classes from synthetic inventory smoke test. */
if .RxBifBreadthRule_XRANGE~argumentRange \== '0 -2' then exit 1
if .RxBifBreadthRule_MAX~routeKind \== 'ISOLATED_REXX' then exit 2
if .RxBifBreadthRule_ARG~routeKind \== 'HOST_ACTIVATION' then exit 3
if .RxBifBreadthRule_DATE~emitCppExpression('slots','clock') \== ,
 'rxbif_breadth_generated::BIF_DATE(slots,clock)' then exit 4
if .RxBifBreadthRule_ABS~routeKind \== 'RX2CPP_BASE_SUBSET' then exit 5
if .RxBifBreadthRule_MAX~requiresNumericContext \== .true then exit 6
if .RxBifBreadthRule_ARG~requiresNumericContext \== .true then exit 7
if .RxBifBreadthRule_DATE~requiresNumericContext \== .true then exit 8
say 'PASS dynamic-arity, route metadata, base preservation and C++ emission rules'
::requires 'Bif_XRANGE.cls'
::requires 'Bif_MAX.cls'
::requires 'Bif_ARG.cls'
::requires 'Bif_DATE.cls'
::requires 'Bif_ABS.cls'
