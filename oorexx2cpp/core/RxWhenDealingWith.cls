/* A code unit is recognised before its instructions are dispatched.
 * The same statement engine runs in all executable contexts.  The policy of
 * the selected scope controls argument binding, variables, numeric settings,
 * package lookup and traps; the statement grammar must not duplicate them.
 * This class records compile-time contexts, not interpreter activations. */
::class RxCodeScope public
::attribute kind get
::attribute parent get
::attribute source get
::attribute variablePolicy get
::attribute argumentPolicy get
::attribute numericPolicy get
::attribute activation get
::attribute prologEnabled get
::method init
  expose kind parent source variablePolicy argumentPolicy numericPolicy activation prologEnabled
  use arg kind, parent, source
  prologEnabled = .true
  if parent \== .nil then prologEnabled = parent~prologEnabled
  select
    when kind == 'PACKAGE' then do
      variablePolicy = 'NONE'; argumentPolicy = 'NONE'; numericPolicy = 'DEFAULT'; activation = .nil
    end
    when kind == 'CLASS' then do
      variablePolicy = 'CLASS'; argumentPolicy = 'NONE'; numericPolicy = 'PACKAGE'; activation = .nil
    end
    when kind == 'PROLOGUE' then do
      variablePolicy = 'LOCAL'; argumentPolicy = 'POSITIONAL_OBJECTS'; numericPolicy = 'PACKAGE'; activation = self
    end
    when kind == 'METHOD' then do
      variablePolicy = 'LOCAL_WITH_OBJECT_EXPOSE'; argumentPolicy = 'POSITIONAL_OBJECTS'; numericPolicy = 'PACKAGE'; activation = self
    end
    when kind == 'ROUTINE' then do
      variablePolicy = 'ISOLATED'; argumentPolicy = 'POSITIONAL_OBJECTS'; numericPolicy = 'PACKAGE'; activation = self
    end
    when kind == 'LABEL' then do
      variablePolicy = 'CALLER'; argumentPolicy = 'POSITIONAL_OBJECTS'; numericPolicy = 'INHERIT'; activation = self
    end
    when kind == 'PROCEDURE' then do
      variablePolicy = 'ISOLATED_EXPOSE'; argumentPolicy = 'POSITIONAL_OBJECTS'; numericPolicy = 'INHERIT'; activation = self
    end
    when kind == 'SIGNAL' then do
      variablePolicy = 'SAME_ACTIVATION'; argumentPolicy = 'SAME_ACTIVATION'; numericPolicy = 'SAME_ACTIVATION'
      activation = parent~activation
    end
    otherwise raise syntax 40.1 array('rx2cpp: unknown code scope ' || kind)
  end
/* ---- policy queries: the statement rules ask the scope, they never test which kind of unit they are in ---- */
/* Kind of the enclosing activation body (a SIGNAL block belongs to the activation it traps; package level is the
   program's entry function). */
::method activationKind
  expose kind activation
  if activation == .nil | activation == self then return kind
  return activation~activationKind
/* The program entry function (main prologue): its RETURN/EXIT leave the process, it has no argument array of its own. */
::method isEntryFunction
  k = self~activationKind
  return k == 'PACKAGE' | k == 'PROLOGUE' | k == 'CLASS'
/* EXIT ends the whole program here (main code and internal label routines); in ::ROUTINE and ::METHOD it only leaves
   the code unit with the value, exactly like RETURN (ooRexx 5.3: routine -> 5, method -> 6, label -> process status). */
::method exitEndsProgram
  k = self~activationKind
  return k \== 'ROUTINE' & k \== 'METHOD'
/* RETURN leaves a callable unit with a message result; in the entry function it is the process status. */
::method returnsMessageResult
  return \self~isEntryFunction
::method bindsArguments
  return \self~isEntryFunction
::method isolatesVariables
  return self~variablePolicy == 'ISOLATED'
::method needsExplicitReturn
  return self~variablePolicy == 'CALLER'
::method allowsInnerLabels
  return self~variablePolicy \== 'ISOLATED'
::method isolatedRoutineKind
  return self~activationKind == 'ROUTINE'
::method setPrologEnabled
  expose prologEnabled kind
  use arg enabled
  if kind \= 'PACKAGE' then raise syntax 40.1 array('rx2cpp: prologue policy belongs to package')
  prologEnabled = enabled

::class RxWhenDealingWith public
::method init
  expose stack
  stack = .array~new
  self~setScope('PACKAGE', 'PACKAGE')
::method depth
  expose stack
  return stack~items
::method current
  expose stack
  if stack~items == 0 then return .nil
  return stack[stack~items]
::method packageScope
  expose stack
  if stack~items == 0 then return .nil
  return stack[1]
/* Lexer recognition, never POS('::CLASS') on raw text: strings and comments
 * must not create phantom code-unit boundaries.  The caller selects PROLOGUE
 * for the lexical region before the first directive. */
::method identify
  use arg block
  tokens = .RxLexer~new(block)~scan
  i = 1
  do while i <= tokens~items & tokens[i]~kind == 'SEP'
    i += 1
  end
  if i > tokens~items | tokens[i]~kind == 'EOF' then return 'EMPTY'
  if tokens[i]~text == '::' & i < tokens~items then do
    kind = tokens[i+1]~text
    if kind == 'CLASS' | kind == 'METHOD' | kind == 'ROUTINE' then return kind
    if kind == 'OPTIONS' then return 'PACKAGE_OPTIONS'
    return 'PACKAGE_DIRECTIVE'
  end
  if tokens[i]~kind == 'IDENT' then do
    if tokens[i]~text == 'PROCEDURE' then return 'PROCEDURE'
    if tokens[i]~text == 'SIGNAL' then return 'SIGNAL'
  end
  return 'LOGIC'
/* SetScope takes a block and its established lexical context.  A class
 * directive alone does not introduce an executable Rexx activation. */
::method setScope
  expose stack
  use arg block, explicitKind = ''
  kind = explicitKind~translate
  if kind == '' then kind = self~identify(block)
  if kind == 'EMPTY' | kind == 'LOGIC' | kind == 'PACKAGE_OPTIONS' | kind == 'PACKAGE_DIRECTIVE' then
    raise syntax 40.1 array('rx2cpp: executable clauses belong to an existing scope: ' || kind)
  parent = self~current
  if kind == 'PACKAGE' then do
    if parent \== .nil then raise syntax 40.1 array('rx2cpp: package scope already active')
  end
  else do
    if parent == .nil then raise syntax 40.1 array('rx2cpp: missing package scope')
    if kind == 'PROLOGUE' | kind == 'CLASS' | kind == 'ROUTINE' then do
      if parent~kind \= 'PACKAGE' then raise syntax 40.1 array('rx2cpp: ' || kind || ' requires package scope')
    end
    if kind == 'METHOD' then do
      if parent~kind \= 'CLASS' & parent~kind \= 'PACKAGE' then
        raise syntax 40.1 array('rx2cpp: METHOD requires class or package scope')
    end
    if kind == 'PROCEDURE' then do
      if parent~kind \= 'LABEL' & parent~kind \= 'METHOD' & parent~kind \= 'ROUTINE' & parent~kind \= 'PROLOGUE' then
        raise syntax 40.1 array('rx2cpp: PROCEDURE requires an executable routine context')
    end
    if kind == 'SIGNAL' & parent~activation == .nil then
      raise syntax 40.1 array('rx2cpp: SIGNAL requires an executable activation')
  end
  record = .RxCodeScope~new(kind, parent, block)
  stack~append(record)
  return record
::method endScope
  expose stack
  if stack~items <= 1 then raise syntax 40.1 array('rx2cpp: cannot close package scope')
  return stack~remove(stack~items)
::method setPrologPolicy
  use arg enabled
  self~packageScope~setPrologEnabled(enabled)
::method shouldRunPrologue
  use arg entryMode
  mode = entryMode~translate
  select
    when mode == 'DIRECT' then return .true
    when mode == 'REQUIRE' then return self~packageScope~prologEnabled
    otherwise raise syntax 40.1 array('rx2cpp: unknown prologue entry mode ' || entryMode)
  end
/* One call site for a clause.  Both standalone and hybrid compiler contexts
 * implement rexxInstruction(depth), so the scope engine never chooses between
 * BIF parsers or supplies an alternate grammar. */
::method rexxLogic
  use arg compiler, depth = 0
  scope = self~current
  if scope == .nil | scope~kind == 'PACKAGE' | scope~kind == 'CLASS' then
    raise syntax 40.1 array('rx2cpp: Rexx logic requires executable scope')
  compiler~rexxInstruction(depth)
::requires 'core/RxLexer.cls'
