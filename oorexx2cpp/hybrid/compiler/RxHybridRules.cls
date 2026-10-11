/* Language rules remain separate loadable ooRexx classes. */
::class RxHybridRules subclass RxRexxRuleSelection public
::method init
  expose entries
  entries = .array~of(.RxHybridExpose~new, .RxHybridUseArg~new, .RxHybridReturn~new, .RxHybridForward~new, .RxHybridGuard~new, .RxHybridNumeric~new, .RxHybridStdStatement~new(.RxStmtIf~new), .RxHybridStdStatement~new(.RxStmtDoUntil~new), .RxHybridStdStatement~new(.RxStmtDoWhile~new), .RxHybridStdStatement~new(.RxStmtDoForever~new), .RxHybridStdStatement~new(.RxStmtCountedDo~new), .RxHybridStdStatement~new(.RxStmtRepeatDo~new), .RxHybridStdStatement~new(.RxStmtLeaveIterate~new), .RxHybridMessageStatement~new, .RxHybridStdStatement~new(.RxStmtParse~new), .RxHybridStdStatement~new(.RxStmtRaise~new), .RxHybridStdStatement~new(.RxStmtCall~new), .RxHybridStdStatement~new(.RxStmtExit~new), .RxHybridStdStatement~new(.RxStmtNop~new), .RxHybridStdStatement~new(.RxStmtSay~new), .RxHybridStdStatement~new(.RxStmtSelect~new), .RxHybridStdStatement~new(.RxStmtLoopOver~new), .RxHybridStdStatement~new(.RxStmtIndexedAssign~new), .RxHybridStdStatement~new(.RxStmtCompoundAssign~new), .RxHybridStdStatement~new(.RxStmtAssign~new))
::method rules
  expose entries
  return entries
::requires 'hybrid/rules/HybridExpose.cls'
::requires 'hybrid/rules/HybridUseArg.cls'
::requires 'hybrid/rules/HybridReturn.cls'
::requires 'hybrid/rules/HybridForward.cls'
::requires 'hybrid/rules/HybridGuard.cls'
::requires 'hybrid/rules/HybridMessageStatement.cls'
::requires 'hybrid/rules/HybridAssign.cls'
::requires 'hybrid/rules/HybridNumeric.cls'
::requires 'hybrid/rules/HybridIf.cls'
::requires 'hybrid/rules/HybridStdStatement.cls'

::requires 'core/RxRexxRuleSelection.cls'
