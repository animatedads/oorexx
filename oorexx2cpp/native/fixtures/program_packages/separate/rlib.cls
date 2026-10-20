::class runner public
::method run
  use arg name
  r = .context~package~findRoutine(name)
  return r~callWith(.array~of(1, 2))
::routine bad public
  return ''~category
::routine good public
  return 'good' arg(1) arg(2)
