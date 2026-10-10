::class RootA public
::method init
  return
::class RootB public
::method init
  return
::class MixB public mixinclass RootB
::method name
  return 'bad'
::class ChildA public subclass RootA inherit MixB
::method name
  return 'bad'
