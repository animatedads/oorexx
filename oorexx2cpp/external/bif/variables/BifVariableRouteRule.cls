/* ooRexx authority: verify source BIF definitions before generating C++.
   These anchors detect signature and key semantic-call drift, but do not
   constitute a proof of equivalence for all interpreter paths. */
::class BifVariableRouteRule public
::method convert
  use arg definition
  n = definition~name
  source = definition~joined
  select
    when n == 'SYMBOL' then do
      if definition~minArg \= 1 | definition~maxArg \= 1 then return .false
      if pos('fix_args(SYMBOL);',source) == 0 then return .false
      if pos('VariableDictionary::getVariableRetriever(name)',source) == 0 then return .false
      if pos('variable->exists(context)',source) == 0 then return .false
      if pos('GlobalNames::BAD',source) == 0 | pos('GlobalNames::LIT',source) == 0 then return .false
      if pos('GlobalNames::VAR',source) == 0 then return .false
      return .true
    end
    when n == 'VAR' then do
      if definition~minArg \= 1 | definition~maxArg \= 1 then return .false
      if pos('fix_args(VAR);',source) == 0 then return .false
      if pos('VariableDictionary::getVariableRetriever(variable)',source) == 0 then return .false
      if pos('retriever->exists(context)',source) == 0 then return .false
      if pos('isString(retriever)',source) == 0 then return .false
      return .true
    end
    when n == 'VALUE' then do
      if definition~minArg \= 1 | definition~maxArg \= 3 then return .false
      if pos('fix_args(VALUE);',source) == 0 then return .false
      if pos('optional_argument(VALUE, newValue)',source) == 0 then return .false
      if pos('optional_string(VALUE, selector)',source) == 0 then return .false
      if pos('VariableDictionary::getVariableRetriever(variable)',source) == 0 then return .false
      if pos('retriever->getValue(context)',source) == 0 then return .false
      if pos('retriever->assign(context, newvalue)',source) == 0 then return .false
      if pos('TheEnvironment->entry(variable)',source) == 0 then return .false
      if pos('SystemInterpreter::getEnvironmentVariable',source) == 0 then return .false
      if pos('SystemInterpreter::valueFunction',source) == 0 then return .false
      return .true
    end
    otherwise return .false
  end
