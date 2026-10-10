/* Language rules remain separate loadable ooRexx classes. */
::class RxHybridRules public
::method init
  expose entries
  entries = .array~of(.RxHybridExpose~new, .RxHybridUseArg~new, .RxHybridReturn~new, .RxHybridForward~new, .RxHybridNumeric~new, .RxHybridIf~new, .RxHybridDo~new, .RxHybridAssign~new)
::method find
  expose entries
  use arg compiler
  do rule over entries
    if rule~accepts(compiler) then return rule
  end
  return .nil
::requires 'hybrid/rules/HybridExpose.cls'
::requires 'hybrid/rules/HybridUseArg.cls'
::requires 'hybrid/rules/HybridReturn.cls'
::requires 'hybrid/rules/HybridForward.cls'
::requires 'hybrid/rules/HybridAssign.cls'
::requires 'hybrid/rules/HybridNumeric.cls'
::requires 'hybrid/rules/HybridIf.cls'
::requires 'hybrid/rules/HybridDo.cls'
