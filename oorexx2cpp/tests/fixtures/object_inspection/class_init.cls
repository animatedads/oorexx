::class A public
::method init class
  say 'SHOULD NOT RUN CLASS INIT'
  return
::method init
  return 'instance init'
::method ordinary
  return 'okay'
