/* Language-defined PARSE input providers, independently replaceable from
   the template grammar and statement rule. Standalone executable backend.
   Metadata is embedded by the ooRexx precompiler, never inferred from an
   arbitrary C++ binary path. Native .so activations need a separate provider.
*/
::class RxParseSourceModes public
::method expression class
  use arg ctx, mode, argIndex
  select
    when mode == 'ARG' then do
      return 'rx::argumentAt(_rxProgramArgs, ' || argIndex || ')'
    end
    when mode == 'SOURCE' & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \= '' then do
      /* A method of a native library: the interpreter's system name, METHOD, the class's original source file. A package
         routine: its call type, SUBROUTINE or FUNCTION, as its compiled caller called it (a routine called by the
         interpreter cannot know it: a run-time error). */
      /* a compiled program's main code (compile_program.sh): COMMAND, as the program it was */
      if ctx~className == 'RX2CPP_ROUTINE_IMPL' & ctx~hasMethod('CURRENT') then if ctx~current \== .nil then
        if ctx~current~selector == 'RX2CPP_MAIN' then
          return 'rx::Value::string(rx::interpreterSystem() + ' || .RxQuote~cpp(' COMMAND ' || ctx~sourceName) || ')'
      if ctx~className == 'RX2CPP_ROUTINE_IMPL' then
        return 'rx::Value::string(rx::interpreterSystem() + " " + rx::ActivationScope::routineCallType() + ' || .RxQuote~cpp(' ' || ctx~sourceName) || ')'
      return 'rx::Value::string(rx::interpreterSystem() + ' || .RxQuote~cpp(' METHOD ' || ctx~sourceName) || ')'
    end
    when mode == 'SOURCE' then do
      return 'rx::sourceDescriptor(' || .RxQuote~cpp(ctx~sourceName) || ')'
    end
    when mode == 'VERSION' & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \= '' then
      /* A native library runs inside the interpreter: PARSE VERSION is the interpreter's own. */
      return 'rx::interpreterVersion()'
    when mode == 'VERSION' then do
      /* The reference ooRexx version used to compile the source. An
         explicit COMPILED suffix distinguishes native execution. */
      return 'rx::Value::string(' || .RxQuote~cpp(ctx~rexxVersion || ' COMPILED') || ')'
    end
    otherwise ctx~stream~fail('unsupported PARSE input mode: ' || mode)
  end
::requires 'core/RxQuote.cls'
