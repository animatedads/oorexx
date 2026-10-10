/* ooRexx source-verified control-state BIF rule. Do not inline synthetic
   TRACE/CONDITION/SOURCELINE semantics into a different Rexx activation. */
::class BifControlRouteRule public
::method convert
  use arg definition
  n = definition~name
  /* Gate on comment/string-masked source, not raw text: a stale call-site
     in a C++ comment MUST NOT authorise the BIF route. */
  source = ''
  lexical = .BifSourceReader~new~maskSource(definition~joined~makeArray('0a'x))
  do sourceLine over lexical
    source ||= sourceLine || '0a'x
  end
  select
    when n == 'SOURCELINE' then do
      if definition~minArg \= 0 | definition~maxArg \= 1 then return .false
      if pos('fix_args(SOURCELINE);',source) == 0 then return .false
      if pos('context->getEffectivePackageObject()',source) == 0 then return .false
      if pos('package->sourceSize()',source) == 0 then return .false
      if pos('package->getLine(line_number)',source) == 0 then return .false
      return .true
    end
    when n == 'TRACE' then do
      if definition~minArg \= 0 | definition~maxArg \= 1 then return .false
      if pos('fix_args(TRACE);',source) == 0 then return .false
      if pos('context->traceSetting()',source) == 0 then return .false
      if pos('context->setTrace(setting)',source) == 0 then return .false
      return .true
    end
    when n == 'CONDITION' then do
      if definition~minArg \= 0 | definition~maxArg \= 1 then return .false
      if pos('fix_args(CONDITION);',source) == 0 then return .false
      if pos('context->getConditionObj()',source) == 0 then return .false
      if pos('context->setConditionObj(OREF_NULL)',source) == 0 then return .false
      if pos('context->trapState(',source) == 0 then return .false
      if pos('conditionobj->copy()',source) == 0 then return .false
      return .true
    end
    otherwise return .false
  end

::requires 'compiler/BifSourceReader.cls'
