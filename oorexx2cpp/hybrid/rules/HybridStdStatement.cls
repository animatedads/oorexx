/* Runs a standalone-compiler statement rule inside the native lane (one rule, two lanes). */
::class RxHybridStdStatement public
::method init
  expose inner
  use arg inner
::method inner
  expose inner
  return inner
::method accepts
  expose inner
  use arg ctx
  return inner~accepts(ctx)
::method emit
  expose inner
  use arg ctx
  inner~emit(ctx, 0)
::requires 'rules/StmtDo.cls'
::requires 'rules/StmtLeaveIterate.cls'
::requires 'rules/StmtIf.cls'
::requires 'rules/StmtParse.cls'
::requires 'rules/StmtSay.cls'
::requires 'rules/StmtSelect.cls'
::requires 'rules/StmtIndexedAssign.cls'
::requires 'rules/StmtCompoundAssign.cls'
::requires 'rules/StmtRaise.cls'
::requires 'rules/StmtCall.cls'
::requires 'rules/StmtExit.cls'
::requires 'rules/StmtNop.cls'
::requires 'rules/StmtDrop.cls'
::requires 'rules/StmtQueue.cls'
::requires 'rules/StmtAssign.cls'
::requires 'rules/StmtAddress.cls'
::requires 'rules/StmtTrace.cls'
