if .RxBifVariableRule_SYMBOL~bifName \== 'SYMBOL' then raise syntax 40.900
if .RxBifVariableRule_VAR~bifName \== 'VAR' then raise syntax 40.900
if .RxBifVariableRule_VALUE~bifName \== 'VALUE' then raise syntax 40.900
if .RxBifVariableRule_SYMBOL~argumentRange \== '1 1' then raise syntax 40.900
if .RxBifVariableRule_VALUE~argumentRange \== '1 3' then raise syntax 40.900
if .RxBifVariableRule_VALUE~routeKind \== 'COMPILED_VARIABLE_SCOPE' then raise syntax 40.900
if .RxBifVariableRule_VAR~emitCppExpression('scope','args') \== 'rxbif_variables_generated::BIF_VAR(scope, args)' then raise syntax 40.900
say 'PASS ooRexx-generated SYMBOL/VAR/VALUE rules'
::requires 'Bif_SYMBOL.cls'
::requires 'Bif_VAR.cls'
::requires 'Bif_VALUE.cls'
