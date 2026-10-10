::class BifRuleEngine public
::method init
  expose rules reason
  rules = .array~of(.BifClockRule~new, .BifMethodRule~new)
  reason = ''
::attribute reason get
::method convert
  expose rules reason
  use arg definition
  name = definition~name
  reason = 'native coverage absent'
  if \.BifNativeCatalog~supports(name) then return .nil
  expected = .BifNativeCatalog~signature(name)
  if definition~minArg < 0 | definition~maxArg < 0 then do
    reason = 'unresolved source arity'
    return .nil
  end
  if definition~minArg \= word(expected,1) | definition~maxArg \= word(expected,2) then do
    reason = 'upstream arity differs from qualified native ABI'
    return .nil
  end
  do rule over rules
    if rule~accept(definition) then do
      ir = rule~convert(definition)
      if ir \== .nil then do
        if name \= 'DATE' & name \= 'TIME' then do
          if ir~method \== word(expected,3) then do
            reason = 'source method changed from qualified native method'
            return .nil
          end
        end
        return ir
      end
      reason = 'source pattern does not match the conversion rule'
      return .nil
    end
  end
  reason = 'no source-to-IR rule'
  return .nil
::requires 'rules/BifNativeCatalog.cls'
::requires 'rules/BifClockRule.cls'
::requires 'rules/BifMethodRule.cls'
