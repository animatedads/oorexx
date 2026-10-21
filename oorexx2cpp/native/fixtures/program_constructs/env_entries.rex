/* environment entries that are not classes: strings (each evaluation sees the current value), objects */
.environment~rx2cpp.envtest = 'a'
do i = 1 to 2
  say .rx2cpp.envtest .rx2cpp.envtest~length (.rx2cpp.envtest == 'a') .rx2cpp.envtest~isA(.String)
  .environment~rx2cpp.envtest = 'bb'
end
.local~rx2cpp.envobj = .array~of(1, 2)
say .rx2cpp.envobj~items
say .rx2cpp.nosuch
say e()
::routine e public
  return 'x'
