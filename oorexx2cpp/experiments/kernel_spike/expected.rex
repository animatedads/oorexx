/* Reference output from the real interpreter, same case file and same output format as probe.cpp.
   usage: rexx expected.rex cases.txt */
parse arg file
do line over .stream~new(file)~arrayIn
  if line == '' | line~left(1) == '#' then iterate
  f = .array~new; rest = line
  do forever
    p = rest~pos('|')
    if p == 0 then do; f~append(rest); leave; end
    f~append(rest~left(p - 1)); rest = rest~substr(p + 1)
  end
  n = f~items
  if n == 2 & f[2] == '' then n = 1   /* NAME| means NO arguments, like NAME() */
  call = f[1] || '('
  do i = 2 to n
    if i > 2 then call = call || ','
    if f[i] == '<empty>' then call = call || "''"
    else if f[i] \== '' then call = call || "'" || f[i]~changeStr("'", "''") || "'"
  end
  call = call || ')'
  say line '=>' evaluate(call)
end
exit 0

evaluate: procedure
  use arg call
  signal on syntax name failed
  interpret 'r =' call
  return '[' || r || ']'
failed:
  return 'ERROR'
