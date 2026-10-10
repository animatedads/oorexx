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
::method addInstruction
  expose instructions seenStatement hasReturn
  use arg line
  if hasReturn then raise syntax 40.1 array('rx2cpp: statement after RETURN is not supported')
  instructions~append(line)
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
