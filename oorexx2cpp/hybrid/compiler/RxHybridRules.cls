/* Language rules remain separate loadable ooRexx classes. */
::class RxHybridRules subclass RxRexxRuleSelection public
::method init
  expose entries
  entries = .array~of(.RxHybridSignal~new, .RxHybridProcedure~new, .RxHybridExpose~new, .RxHybridUseLocal~new, .RxHybridUseArg~new, .RxHybridReturn~new, .RxHybridReply~new, .RxHybridForward~new, .RxHybridGuard~new, .RxHybridNumeric~new, .RxHybridStdStatement~new(.RxStmtIf~new), .RxHybridStdStatement~new(.RxStmtDo~new), .RxHybridStdStatement~new(.RxStmtLeaveIterate~new), .RxHybridInterpret~new, .RxHybridMessageStatement~new, .RxHybridStdStatement~new(.RxStmtParse~new), .RxHybridStdStatement~new(.RxStmtRaise~new), .RxHybridStdStatement~new(.RxStmtCall~new), .RxHybridStdStatement~new(.RxStmtExit~new), .RxHybridStdStatement~new(.RxStmtNop~new), .RxHybridStdStatement~new(.RxStmtDrop~new), .RxHybridStdStatement~new(.RxStmtQueue~new), .RxHybridStdStatement~new(.RxStmtSay~new), .RxHybridStdStatement~new(.RxStmtTrace~new), .RxHybridStdStatement~new(.RxStmtSelect~new), .RxHybridStdStatement~new(.RxStmtAddress~new), .RxHybridCommand~new, .RxHybridStdStatement~new(.RxStmtIndexedAssign~new), .RxHybridStdStatement~new(.RxStmtCompoundAssign~new), .RxHybridStdStatement~new(.RxStmtAssign~new))
::method rules
  expose entries
  return entries
::requires 'hybrid/rules/HybridSignal.cls'
::requires 'hybrid/rules/HybridProcedure.cls'
::requires 'hybrid/rules/HybridCommand.cls'
::requires 'hybrid/rules/HybridExpose.cls'
::requires 'hybrid/rules/HybridUseArg.cls'
::requires 'hybrid/rules/HybridUseLocal.cls'
::requires 'hybrid/rules/HybridReturn.cls'
::requires 'hybrid/rules/HybridReply.cls'
::requires 'hybrid/rules/HybridForward.cls'
::requires 'hybrid/rules/HybridGuard.cls'
::requires 'hybrid/rules/HybridMessageStatement.cls'
::requires 'hybrid/rules/HybridAssign.cls'
::requires 'hybrid/rules/HybridNumeric.cls'
::requires 'hybrid/rules/HybridIf.cls'
::requires 'hybrid/rules/HybridInterpret.cls'
::requires 'hybrid/rules/HybridStdStatement.cls'

::requires 'core/RxRexxRuleSelection.cls'
