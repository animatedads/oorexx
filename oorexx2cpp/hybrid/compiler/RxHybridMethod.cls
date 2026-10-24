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
::attribute labels get          /* label name -> case index (1..n), for SIGNAL and SIGNAL ON ... NAME */
::attribute trapped get         /* the body has labels or SIGNAL: it runs inside a trap loop */
/* Internal routines of this method (labels used by CALL name / name(...)): label -> directory PROCEDURE, EXPOSE. */
::method setInternalCalls
  expose internalCalls
  use arg internalCalls
::method internalCalls
  expose internalCalls
  if var('INTERNALCALLS') then return internalCalls
  return .directory~new
::method hasInternalCalls
  return self~internalCalls~items > 0
/* A method the compiler made (the default INIT of a root class that declares none: RxHybridCompiler~ensureInit). */
::method setSynthetic
  expose synthetic
  use arg synthetic
::method synthetic
  expose synthetic
  if var('SYNTHETIC') then return synthetic
  return .false
/* SELF is a variable of this method (RxStream~methodBodySelfVariable): set at the start, read as a variable. */
::method setSelfVariable
  expose selfVariable
  use arg selfVariable
::method selfVariable
  expose selfVariable
  if var('SELFVARIABLE') then return selfVariable
  return .false
/* The body has CALL ON: its handlers are called at clause boundaries (_rxCallOn after each statement). */
::method setCallOn
  expose callOn
  use arg callOn
::method callOn
  expose callOn
  if var('CALLON') then return callOn
  return .false
/* CALL ON ... NAME x where x is no label of the method: the handler is a routine (package or external), called with
   the condition object as the internal handlers are (RexxActivation trap handling: CALL x). Index k >= 0 is label
   value -2 - k in the trap table. */
::method callOnExternal
  expose callOnExternal
  if \var('CALLONEXTERNAL') then callOnExternal = .array~new
  return callOnExternal
::method externalHandler
  use arg name
  list = self~callOnExternal
  do k = 1 to list~items
    if list[k] == name then return -1 - k
  end
  list~append(name)
  return -1 - list~items
/* The body has GUARD: the method manages its object lock (see HybridGuard). */
::method setGuards
  expose guards
  use arg guards
::method guards
  expose guards
  if var('GUARDS') then return guards
  return .false
/* The body has REPLY: RETURN / EXIT with a value check that no reply was made (rx::afterReply). */
::method setReplies
  expose replies
  use arg replies
::method replies
  expose replies
  if var('REPLIES') then return replies
  return .false
::method setTraps
  expose labels trapped
  use arg names, trapped
  labels = .directory~new
  do i = 1 to names~items
    if \labels~hasIndex(names[i]) then labels[names[i]] = i
  end
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
  expose selector parameter parameters exposed instructions hasReturn seenStatement guard attributeSetter options isAbstract labels trapped
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
  labels = .directory~new
  trapped = .false
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
  expose instructions hasReturn trapped
  use arg cpp
  if hasReturn & \trapped then raise syntax 40.1 array('rx2cpp: NUMERIC after RETURN')
  instructions~append(cpp)
::method addInstruction
  expose instructions seenStatement hasReturn trapped
  use arg line
  /* In a trap loop a RETURN ends only its own path: labels and handlers follow it. */
  if hasReturn & \trapped then raise syntax 40.1 array('rx2cpp: statement after RETURN is not supported')
  instructions~append(line)
  seenStatement = .true
/* Variable access sites read and write through the activation's slot table (rx::LocalSlots _rxL): each variable
   name of the body gets a slot number, RX_VGET("N") becomes RX_VGETK(k, "N") (and RX_VREF, RX_VTAIL, RX_VSET), and
   the table is declared first in the body. Internal routines (the body function entered again) share it: one that
   shares its caller's variables finds its slots filled; a PROCEDURE pool is another pool, so its slots are found
   again (each slot is checked against the pool). */
::method useLocalSlots
  expose instructions
  use arg internalCalls
  macros = .array~of('RX_VGET("', 'RX_VREF("', 'RX_VTAIL("', 'RX_VSET("', 'RX_VSTEM("', 'RX_NGET("', 'RX_NSET("', 'RX_NPUT("', 'RX_NINV("', 'RX_NCOPY("', 'RX_NFROM("', 'RX_NCANON("', 'RX_NHOLDS("')
  slot = .directory~new
  count = 0
  rewritten = .array~new
  do line over instructions
    if line~pos('RX_V') > 0 | line~pos('RX_N') > 0 then line = self~slotLine(line, macros, slot)
    rewritten~append(line)
  end
  count = slot~items
  natives = .RxNative~enabled
  /* (an internal routine call keeps the caller's slots: the table is declared when there is one, even empty) */
  if count == 0 & \natives & \internalCalls then return
  /* (a body without variables still clears its registers after calls: a table of one) */
  declaration = 'rx::LocalSlots<' || max(count, 1) || '> _rxL{}; (void)_rxL;'
  /* The activation's frame (rx::Frame): the body's simple variables by slot number, not by name. The names, in slot
     order, are made once (a static); a PROCEDURE pool of an internal routine gets its own frame from the same names. */
  ordered = .array~new(max(count, 1))
  do name over slot~allIndexes
    ordered[slot[name] + 1] = name
  end
  names = ''
  do i = 1 to count
    if names \== '' then names = names || ', '
    names = names || '"' || ordered[i] || '"'
  end
  declaration = declaration 'static const rx::FrameNames _rxFN{' || names || '}; rx::Frame<' || max(count, 1) || '> _rxF(vars, _rxFN);'
  /* Native registers (RxNative) for this body: a method with EXPOSE has them only when no other activity can change
     its object variables while it runs */
  /* (EXPOSE: only in a class where no other activity can run one of its methods meanwhile: RxHybridCompiler~parse) */
  nativeOn = self~exposed~items == 0 | .local['RX2CPP.CLASSCONCURRENT'] == 0
  if natives then declaration = declaration '[[maybe_unused]] constexpr bool _rxNOn =' word('false true', 1 + nativeOn) || ';'
  instructions = .array~of(declaration)
  do line over rewritten
    instructions~append(line)
  end
/* One line of generated C++ with its variable macros numbered: only macros in the code, not text inside a C++ string or
   character literal (a compiled Rexx literal 'RX_VGET(' is C++ "RX_VGET(" and stays as it is). */
::method slotLine private
  use arg line, macros, slot
  at = 1          /* scanned up to here, outside any literal */
  do forever
    /* the next macro start after at */
    p = 0
    do m over macros
      q = line~pos(m, at)
      if q > 0 & (p = 0 | q < p) then do; p = q; found = m; end
    end
    if p = 0 then return line
    /* is p inside a literal? walk the quotes between at and p */
    inString = .false
    i = at
    do forever
      q = line~pos('"', i)
      if q = 0 | q >= p then leave
      if \inString & q > 1 & line~substr(q - 1, 1) == "'" & line~substr(q + 1, 1) == "'" then do; i = q + 2; iterate; end
      if \inString & q > 2 & line~substr(q - 2, 2) == "'\" & line~substr(q + 1, 1) == "'" then do; i = q + 2; iterate; end
      if inString then do
        backslashes = 0
        k = q - 1
        do while k >= i - 1 & k > 0 & line~substr(k, 1) == '\'
          backslashes += 1
          k -= 1
        end
        if backslashes // 2 = 1 then do; i = q + 1; iterate; end
      end
      inString = \inString
      i = q + 1
    end
    if inString then do
      /* skip to the end of this literal: the next unescaped quote after p */
      q = p
      do forever
        q = line~pos('"', q)
        if q = 0 then return line
        backslashes = 0
        k = q - 1
        do while k > 0 & line~substr(k, 1) == '\'
          backslashes += 1
          k -= 1
        end
        if backslashes // 2 = 0 then leave
        q += 1
      end
      at = q + 1
      iterate
    end
    nameStart = p + length(found)
    q = line~pos('"', nameStart)
    if q = 0 then return line
    name = line~substr(nameStart, q - nameStart)
    if \slot~hasEntry(name) then slot[name] = slot~items
    repl = found~left(length(found) - 2) || 'K(' || slot[name] || ', "'
    line = line~left(p - 1) || repl || line~substr(nameStart)
    at = p + length(repl) + (q - nameStart) + 1     /* past the name's closing quote */
  end
/* Generated scaffolding (trap loop, SIGL line markers): not a Rexx statement (EXPOSE / USE ARG may still follow). */
::method addRaw
  expose instructions
  use arg line
  instructions~append(line)
/* A RETURN inside IF/DO exits at run time only if its branch is taken.
   The enclosing method must still have an unconditional final RETURN in
   the current restricted ABI, so this does not mark hasReturn. */
::method branchReturnValue
  expose instructions seenStatement hasReturn trapped
  use arg expression
  if hasReturn & \trapped then raise syntax 40.1 array('rx2cpp: RETURN after terminal RETURN')
  instructions~append('{ const rx::Value result = ' || expression || ';')
  instructions~append('return result; }')
  seenStatement = .true
::method returnValue
  expose instructions seenStatement hasReturn trapped
  use arg expression
  if hasReturn & \trapped then raise syntax 40.1 array('rx2cpp: duplicate RETURN')
  instructions~append('const rx::Value result = ' || expression || ';')
  instructions~append('return result;')
  seenStatement = .true
  hasReturn = .true
::requires 'rules/RxNative.cls'
