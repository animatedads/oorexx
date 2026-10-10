/* Narrow, independent ooRexx compound-assignment operator ruleset.
   Other ooRexx augmented operators are intentionally not present. */
::class RxCompoundAssignmentOps public
::method isSupported class
  use arg operator
  return wordpos(operator, '+= -= *= /=') > 0
::method selector class
  use arg operator
  select
    when operator == '+=' then return '+'
    when operator == '-=' then return '-'
    when operator == '*=' then return '*'
    when operator == '/=' then return '/'
    otherwise raise syntax 40.1 array ('rx2cpp: unsupported augmented assignment operator ' || operator)
  end
