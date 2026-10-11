/* Run from the rx2cpp source root with REXX_PATH including that root.
 * The sole temporary source copy is supplied by the caller and deleted here.
 * Output is a reversible object-model stream, not a C++ translation. */
parse arg original temporary
tree = .false
if original~translate == '--TREE' then do; tree = .true; parse arg . original temporary; end
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
if tree then do
  /* --tree: temporary is a NEW directory; dependencies are inspected first, each as a neutralised copy */
  call SysMkDir temporary
  walker = .RxRequiresTree~new(temporary)
  inspector~resolver = walker
  inspector~inspect(original, temporary || '/main_' || .File~new(original)~name)
  do d over walker~inspectors
    say 'requires'||'09'x||d[1]
    d[2]~printMap
  end
  say 'requires'||'09'x||original
  inspector~printMap
  do e over walker~edges; say 'edge'||'09'x||e; end
  do m over walker~missing; say 'missing'||'09'x||m; end
  call cleanTree temporary
  exit 0
end
inspector~inspect(original, temporary)
inspector~printMap
call SysFileDelete temporary
exit 0
failed:
  say 'rx2cpp inspector:' condition('A')
  if tree then call cleanTree temporary
  else call SysFileDelete temporary
  exit 65
cleanTree: procedure
  use arg dir
  d = .File~new(dir)
  do f over d~listFiles; call SysFileDelete f~absolutePath; end
  call SysRmDir dir
  return
::requires 'inspector/RxSourceInspector.cls'
::requires 'inspector/RxRequiresTree.cls'
