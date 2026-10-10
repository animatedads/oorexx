say .nil~string
say (.nil == .nil)
say .output~class~id
say (.output == .output)
say .routines~class~id
say .routines~items
say .routines~hasIndex('DEMO')
say .routines~at('DEMO')~class~id
say (.routines == .routines)
say demo()
::routine demo public
  return .nil~string
