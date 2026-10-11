/* A single validated, ooRexx-declared instance method. No shared globals. */
::class RxHybridMethod public
::attribute selector get
::attribute options get
::attribute isAbstract get
::attribute parameter get
::attribute parameters get
::attribute exposed get
::attribute instructions get
::attribute hasReturn get
::attribute seenStatement get
::attribute guard get
::attribute attributeSetter get
::method markAttributeSetter
  expose attributeSetter
  attributeSetter = .true
::method setOptions
  expose options isAbstract guard
  use arg options
  guard = options~guard
  isAbstract = options~isAbstract
::method declaration
  expose options guard
  if options == .nil then return guard
  return options~declaration
::method setGuard
  expose guard
  use arg guard
::method init
  expose selector parameter parameters exposed instructions hasReturn seenStatement guard attributeSetter options isAbstract
  use arg selector
  options = .nil
  isAbstract = .false
  guard = ''
  attributeSetter = .false
  parameter = ''
  parameters = .array~new
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
/* Positional USE ARG names, any number (ARGLIST ABI). `parameter` is the first name. */
::method setParameter
  expose parameter parameters seenStatement
  use arg name
  if seenStatement | parameters~items > 0 then
    raise syntax 40.1 array('rx2cpp: USE ARG may occur only once before statements')
  parameter = name
  parameters~append(name)
::method addParameter
  expose parameters seenStatement
  use arg name
  if seenStatement | parameters~items == 0 then
    raise syntax 40.1 array('rx2cpp: additional USE ARG requires first parameter')
  if parameters~hasItem(name) then
    raise syntax 40.1 array('rx2cpp: duplicate USE ARG parameter ' || name)
  parameters~append(name)
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
