/* THROW (RFE #31, trunk r13547+): caught on its own level and out of routines, internal routines and methods (PROPAGATED),
   THROW SYNTAX / ERROR rc, ARRAY and DESCRIPTION, THROW PROPAGATE (CATCH clause and SIGNAL ON handler), SIGNAL ON takes it
   and CALL ON does not, FINALLY clauses on the way, INTERPRET, a message object's HASERROR, RAISE PROPAGATE of a thrown
   condition, THROW as a variable; a message object's HASERROR for an error too. Claude (Opus 5.5), 2026-11-20. */
out = ''
do
  out = out 'a'
  throw user stop
  out = out 'never'
catch c = user stop
  out = out 'caught' c~thrown c~propagated c~instruction condition('C') condition('I')
end
say out
do
  call loadConfig 'abc'
catch c = user badConfig
  say 'routines:' c~description c~thrown c~propagated
end
do
  call sub
catch c = user sub
  say 'internal:' c~propagated
end
do
  throw user here array (1, 2)
catch c = user here
  say 'array:' c~additional~items c~additional[2] c~propagated
end
do
  call throwError
catch c = error 5
  say 'error:' c~rc c~thrown
end
do
  call throwSyntax
catch c = syntax 40.1
  say 'syntax:' c~code c~message c~thrown
end
do
  call rethrow
catch c = user p
  say 'propagate:' c~description c~thrown
end
do
  call fromSignal
catch c = user s
  say 'from signal:' c~thrown condition('I')
end
do
  call raisePropagate
catch c = user rp
  say 'raise propagate went too far' c~thrown
end
say 'raise propagate: one level'
do
  x = .Tester~new~outer
catch c = user deep
  say 'methods:' c~description c~propagated
end
m = .message~new(.Tester~new, 'inner')
do
  m~send
catch user deep
  say 'message:' m~hasError m~errorCondition~condition m~errorCondition~thrown
end
m = .message~new(.Tester~new, 'divide')
do
  m~send
catch syntax
  say 'message error:' m~hasError m~errorCondition~code m~errorCondition~thrown
end
do
  interpret 'throw user interp description "i"'
catch c = user interp
  say 'interpret:' c~condition c~description c~propagated
end
.local~fx.out = ''
do
  do
    call finallyOuter
  finally
    .local~fx.out = .fx.out 'here'
  end
catch user fin
  .local~fx.out = .fx.out 'caught'
end
say 'finally:' .fx.out
do
  x = finallyReturn()
  say 'returned' x
catch user fin
  say 'finally replaces the result'
end
call on user con name handler
do
  call thrower 'con'
catch user con
  say 'call on: not taken'
end
throw = 3
throw += 1
say 'variable:' throw
signal on user sig name trapped
call thrower 'sig'
say 'never'
exit
handler:
say 'handler!'
return
trapped:
say 'signal on:' condition('C') condition('I') condition('O')~thrown condition('O')~propagated
exit
sub:
call subsub
say 'never'
return
subsub:
throw user sub
::routine loadConfig
  use arg line
  call parseLine line
::routine parseLine
  use arg line
  if pos('=', line) = 0 then throw user badConfig description ("no '=' in" line)
::routine throwError
  throw error 5
::routine throwSyntax
  throw syntax 40.1 array ('XYZ')
::routine rethrow
  do
    throw user p description 'first'
  catch user p
    throw propagate description 'again'
  end
::routine fromSignal
  signal on user s name trapped
  throw user s
trapped:
  throw propagate
::routine raisePropagate
  call raisePropagate2
::routine raisePropagate2
  do
    call thrower 'rp'
  catch user rp
    raise propagate
  end
::routine thrower
  use arg name
  interpret 'throw user' name
::routine finallyOuter
  do
    call finallyInner
  finally
    .local~fx.out = .fx.out 'outer'
  end
::routine finallyInner
  do
    throw user fin
  finally
    .local~fx.out = .fx.out 'inner'
  end
::routine finallyReturn
  do
    return 5
  finally
    throw user fin
  end
::class Tester
::method outer
  return self~middle
::method middle
  return self~inner
::method inner
  throw user deep description 'from inner'
::method divide
  return 1 / 0
