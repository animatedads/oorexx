/* an error in a started message is raised again at ~result in the caller */
m = .T~new~start("BOOM")
signal on syntax name caught
r = m~result
say "NO ERROR SURFACED"
exit
caught:
c = condition('O')
say "caught code" c~code
say "message" c~message
::class T
::method boom unguarded
  x = 1 / 0
