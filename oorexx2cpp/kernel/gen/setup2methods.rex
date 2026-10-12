/* Read ooRexx's own primitive-class method table (interpreter/memory/Setup.cpp) and write it as TSV:
   class side kind name entry args
   Nothing is hand-copied: the kernel's class definitions are the source of truth.
   usage: rexx setup2methods.rex /path/to/Setup.cpp out.tsv */
parse arg source out
if source == '' | out == '' then do; say 'usage: setup2methods.rex Setup.cpp out.tsv'; exit 64; end
if stream(source, 'C', 'QUERY EXISTS') == '' then do; say 'missing' source; exit 66; end
class = ''
rows = 0
tsv = 'class' || '09'x || 'side' || '09'x || 'kind' || '09'x || 'name' || '09'x || 'entry' || '09'x || 'args' || '0a'x
do while lines(source) > 0
  line = strip(linein(source))
  if line~left(2) == '//' | line == '' then iterate
  if line~left(20) == 'StartClassDefinition' then do
    parse var line '(' class ')' .
    class = strip(class)
    iterate
  end
  if line~left(3) \== 'Add' & line~left(6) \== 'Inheri' & line~left(4) \== 'Hide' & line~left(6) \== 'Remove' then iterate
  parse var line macro '(' rest
  macro = strip(macro)
  select
    when macro~left(8) == 'AddClass' then do; side = 'class'; kind = macro~substr(9); end
    when macro~left(3) == 'Add' then do; side = 'instance'; kind = macro~substr(4); end
    otherwise iterate     /* Inherit*, Hide*, Remove*: behaviour edits, not method definitions */
  end
  kind = kind~changeStr('Method', '')
  if kind == '' then kind = 'Public'
  /* ("Name", Class::entry, args) */
  parse var rest '"' name '"' ',' entry ',' args ')'
  name = name~changeStr('\\', '\')
  entry = strip(entry); args = strip(args)
  if entry == '' then iterate
  tsv = tsv || class || '09'x || side || '09'x || kind || '09'x || name || '09'x || entry || '09'x || args || '0a'x
  rows += 1
end
call stream out, 'C', 'CLOSE'
if stream(out, 'C', 'QUERY EXISTS') \== '' then call SysFileDelete out
call charout out, tsv
call stream out, 'C', 'CLOSE'
say 'wrote' rows 'method rows to' out
