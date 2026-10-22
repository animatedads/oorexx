/* findRoutine on the program's own package: the same routine object each time; .nil for an unknown name */
r1 = .context~package~findRoutine('twice')
r2 = .context~package~findRoutine('TWICE')
say (r1 == r2) r1~class~id r1~callWith(.array~of(21))
say .context~package~findRoutine('nosuch') == .nil
p = .context~package
say p~name~right(6) (p == .context~package)
do i = 1 to 3
  say .context~package~findRoutine('twice')~call(i)
end
exit
::routine twice
  return arg(1) * 2
