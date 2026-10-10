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
    when mode == 'SOURCE' then do
      return 'rx::sourceDescriptor(' || .RxQuote~cpp(ctx~sourceName) || ')'
    end
    when mode == 'VERSION' then do
      /* The reference ooRexx version used to compile the source. An
         explicit COMPILED suffix distinguishes native execution. */
      return 'rx::Value::string(' || .RxQuote~cpp(ctx~rexxVersion || ' COMPILED') || ')'
    end
    otherwise ctx~stream~fail('unsupported PARSE input mode: ' || mode)
  end
::requires 'core/RxQuote.cls'
