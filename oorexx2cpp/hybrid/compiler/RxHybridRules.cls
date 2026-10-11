/* Language rules remain separate loadable ooRexx classes. */
::class RxHybridRules subclass RxRexxRuleSelection public
::method init
  expose entries
  entries = .array~of(.RxHybridExpose~new, .RxHybridUseArg~new, .RxHybridReturn~new, .RxHybridForward~new, .RxHybridNumeric~new, .RxHybridIf~new, .RxHybridDo~new, .RxHybridMessageStatement~new, .RxHybridAssign~new)
::method rules
  expose entries
  return entries
::requires 'hybrid/rules/HybridExpose.cls'
::requires 'hybrid/rules/HybridUseArg.cls'
::requires 'hybrid/rules/HybridReturn.cls'
::requires 'hybrid/rules/HybridForward.cls'
::requires 'hybrid/rules/HybridMessageStatement.cls'
::requires 'hybrid/rules/HybridAssign.cls'
::requires 'hybrid/rules/HybridNumeric.cls'
::requires 'hybrid/rules/HybridIf.cls'
::requires 'hybrid/rules/HybridDo.cls'

::requires 'core/RxRexxRuleSelection.cls'
