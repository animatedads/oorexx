say helperPublic()
say .PrivateRoutineHost~new~current
say .PrivateBridge~new~join
say .PrivateBridge~new~constant
signal on syntax name error
say helperPrivate('red', 'blue')
say 'FAIL private global leaked'
exit 5
error:
  say 'private inaccessible'
::requires 'rx2cpp_private_test' library
::requires 'routine_private_bridge_native.cls'
