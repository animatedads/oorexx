/* A single validated, ooRexx-declared instance method. No shared globals. */
::class RxHybridMethod public
::attribute selector get
::attribute parameter get
::attribute secondParameter get
::attribute exposed get
::attribute instructions get
::attribute hasReturn get
::attribute seenStatement get
::attribute guard get
::attribute attributeSetter get
::method markAttributeSetter
  expose attributeSetter
  attributeSetter = .true
::method setGuard
  expose guard
  use arg guard
::method init
  expose selector parameter secondParameter exposed instructions hasReturn seenStatement guard attributeSetter
  use arg selector
  guard = ''
  attributeSetter = .false
  parameter = ''
  secondParameter = ''
  exposed = .array~new
  instructions = .array~new
  hasReturn = .false
  seenStatement = .false
::method addExpose
  expose exposed seenStatement
  use arg name
  if seenStatement then raise syntax 40.1 array('rx2cpp: EXPOSE must precede executable instructions')
  if exposed~hasItem(name) then raise syntax 40.1 array('rx2cpp: duplicate exposed variable ' || name)
  exposed~append(name)
::method setParameter
  expose parameter seenStatement
  use arg name
  if seenStatement | parameter \== '' then raise syntax 40.1 array('rx2cpp: only one leading USE ARG parameter supported')
  parameter = name
::method setSecondParameter
  expose parameter secondParameter seenStatement
  use arg name
  if seenStatement | parameter == '' | secondParameter \== '' then
    raise syntax 40.1 array('rx2cpp: two-argument USE ARG must follow the first parameter')
  if name == parameter then
    raise syntax 40.1 array('rx2cpp: duplicate USE ARG parameter ' || name)
  secondParameter = name
/* NUMERIC alters activation context but does not prevent a subsequent
   USE ARG in the same routine, as the ooRexx interpreter permits. */
::method addNumericInstruction
  expose instructions hasReturn
  use arg cpp
  if hasReturn then raise syntax 40.1 array('rx2cpp: NUMERIC after RETURN')
  instructions~append(cpp)
::method addInstruction
  expose instructions seenStatement hasReturn
  use arg line
  if hasReturn then raise syntax 40.1 array('rx2cpp: statement after RETURN is not supported')
  instructions~append(line)
  seenStatement = .true
/* A RETURN inside IF/DO exits at run time only if its branch is taken.
   The enclosing method must still have an unconditional final RETURN in
   the current restricted ABI, so this does not mark hasReturn. */
::method branchReturnValue
  expose instructions seenStatement hasReturn
  use arg expression
  if hasReturn then raise syntax 40.1 array('rx2cpp: RETURN after terminal RETURN')
  instructions~append('{ const rx::Value result = ' || expression || ';')
  instructions~append('if (result.isObject()) throw std::runtime_error("non-scalar return requires interpreter proxy");')
  instructions~append('return result.bytes; }')
  seenStatement = .true
::method returnValue
  expose instructions seenStatement hasReturn
  use arg expression
  if hasReturn then raise syntax 40.1 array('rx2cpp: duplicate RETURN')
  instructions~append('const rx::Value result = ' || expression || ';')
  instructions~append('if (result.isObject()) throw std::runtime_error("non-scalar return requires interpreter proxy");')
  instructions~append('return result.bytes;')
  seenStatement = .true
  hasReturn = .true
