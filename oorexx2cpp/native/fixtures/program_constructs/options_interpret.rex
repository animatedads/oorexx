/* INTERPRET under ::OPTIONS condition SYNTAX: the string has the policies; a CATCH around it wins; SIGNAL ON turns
   them off. Claude (Opus 5.5), 2026-11-21. */
do
  interpret 'say x'
catch syntax
  say 'interpret:' condition('O')~code
end
do
  interpret 'say y'
catch novalue
  say 'catch novalue around interpret:' condition('D')
end
do
  interpret "'exit 2'"
catch syntax
  say 'interpret command:' condition('O')~code
end
call trapped
exit
trapped:
  signal on novalue name nv
  interpret 'say z'
  say 'never'
  return
nv: say 'signal on novalue:' condition('D'); return
::options novalue syntax error syntax
