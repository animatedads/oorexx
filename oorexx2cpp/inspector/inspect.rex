/* Run from the rx2cpp source root with REXX_PATH including that root.
 * The sole temporary source copy is supplied by the caller and deleted here.
 * Output is a reversible object-model stream, not a C++ translation. */
parse arg original temporary
if original == '' | temporary == '' then do
  say 'Usage: rexx inspector/inspect.rex source.cls temporary.cls'
  exit 64
end
/* Never delete or overwrite a pre-existing caller file, including an
   alias for the original source.  Only our own new temporary is cleaned. */
if original == temporary | stream(temporary, 'C', 'QUERY EXISTS') \== '' then do
  say 'rx2cpp inspector: temporary path must not already exist'
  exit 65
end
signal on syntax name failed
signal on error name failed
signal on failure name failed
inspector = .RxSourceInspector~new
inspector~inspect(original, temporary)
inspector~printMap
call SysFileDelete temporary
exit 0
failed:
  say 'rx2cpp inspector:' condition('A')
  call SysFileDelete temporary
  exit 65
::requires 'inspector/RxSourceInspector.cls'
