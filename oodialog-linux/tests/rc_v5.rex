parsed=.json~fromJsonFile('input_rc_v4.json')
tree=.RcTreeFactory~fromRcJson(parsed)
d=.RcPort~new
call check d~loadRcTree(tree,'IDD_PANEL')=-1,'detect duplicate symbolic ID'
parsed=.json~fromJsonFile('input_rc_unique.json')
tree=.RcTreeFactory~fromRcJson(parsed)
d=.RcPort~new
call check d~loadRcTree(tree,'IDD_PANEL')=0,'import'
call check d~hasControl(701),'symbol resolved'
call check d~getControlText(701)='','edit initially blank'
call check d~getTitle='Tools, Settings','caption'
call check d~control(701)~resourceNode \== .nil,'node linked'
call check d~loadRcTree(tree,'IDD_PANEL')=-1,'duplicate rejection'
call check d~getControlText(701)='','rollback unchanged'
call check d~connectControlEvent(701,'FOCUS','focusHandler')=0,'connect'
handler=.OoDialogRcHandler~new(d,701,'FOCUS')
tree~registerHandler('focusBridge',handler)
tree~find('IDC_NAME')~bind('focus','focusBridge')
ignored=d~emitResourceEvent(701,'focus')
call check d~seen=1,'native event route'
say 'PASS: RC v4 JSON -> V5 live tree -> ooDialog control -> Rexx callback'
exit 0
check: procedure
 use arg ok,tag
 if \ok then do; say 'FAIL:' tag; exit 1; end
 return
::class RcPort subclass UserDialog
::method init
 expose seen
 seen=0
 forward class(super) continue
::method focusHandler
 expose seen
 seen=seen+1
 return 0
::method seen
 expose seen
 return seen
::requires 'ooDialog.cls'