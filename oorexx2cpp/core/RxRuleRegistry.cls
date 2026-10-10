/* Explicit extension registry. The ONLY statement dispatch table.
   To add syntax, write an independently loadable ::class, ::requires it below,
   then register it here in lexical-priority order (fallback assignment last).
   The compiler coordinator does not change for new statement classes. */
::class RxRuleRegistry public
::method init
  expose rules
  rules = .array~new
  rules~append(.RxStmtNumeric~new)
  rules~append(.RxStmtSay~new)
  rules~append(.RxStmtLoopOver~new)
  rules~append(.RxStmtDoUntil~new)
  rules~append(.RxStmtDoWhile~new)
  rules~append(.RxStmtDoForever~new)
  rules~append(.RxStmtCountedDo~new)
  rules~append(.RxStmtRepeatDo~new)
  rules~append(.RxStmtSelect~new)
  rules~append(.RxStmtLeaveIterate~new)
  rules~append(.RxStmtParse~new)
  rules~append(.RxStmtProcedure~new)
  rules~append(.RxStmtUseArg~new)
  rules~append(.RxStmtIf~new)
  rules~append(.RxStmtSignal~new)
  rules~append(.RxStmtRaise~new)
  rules~append(.RxStmtExit~new)
  rules~append(.RxStmtReturn~new)
  rules~append(.RxStmtCall~new)
  rules~append(.RxStmtCompoundAssign~new)
  rules~append(.RxStmtMessage~new)
  rules~append(.RxStmtIndexedAssign~new)
  rules~append(.RxStmtAssign~new)
::method find
  expose rules
  use arg context
  do rule over rules
    if rule~accepts(context) then return rule
  end
  return .nil
::requires 'rules/StmtNumeric.cls'
::requires 'rules/StmtSay.cls'
::requires 'rules/StmtDoUntil.cls'
::requires 'rules/StmtDoWhile.cls'
::requires 'rules/StmtDoForever.cls'
::requires 'rules/StmtCountedDo.cls'
::requires 'rules/StmtRepeatDo.cls'
::requires 'rules/StmtSelect.cls'
::requires 'rules/StmtLeaveIterate.cls'
::requires 'rules/StmtParse.cls'
::requires 'rules/StmtUseArg.cls'
::requires 'rules/StmtProcedure.cls'
::requires 'rules/StmtIf.cls'
::requires 'rules/StmtSignal.cls'
::requires 'rules/StmtRaise.cls'
::requires 'rules/StmtExit.cls'
::requires 'rules/StmtReturn.cls'
::requires 'rules/StmtCall.cls'
::requires 'rules/StmtCompoundAssign.cls'
::requires 'rules/StmtMessage.cls'
::requires 'rules/StmtIndexedAssign.cls'
::requires 'rules/StmtAssign.cls'

::requires 'rules/StmtLoopOver.cls'
