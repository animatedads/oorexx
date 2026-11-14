/* reserved.rex -- write into OodDesigner.cls's ::RESOURCE oodReserved every
   instance method a UserDialog subclass inherits from upstream ooDialog, so
   the designer never gives a control, accessor or attribute one of those names.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage (in the directory holding ooDialog.cls):
     rexx path/to/tools/reserved.rex path/to/src/OodDesigner.cls          */
parse arg target
target = target~strip
if target == "" then do
  say "usage: rexx reserved.rex OodDesigner.cls"
  return 1
end
names = .set~new
s = .UserDialog~methods
do while s~available
  names~put(s~index~lower)
  s~next
end
-- methods the designer writes in every form
do n over .array~of("init", "definedialog", "initdialog", "ok", "cancel")
  names~put(n)
end
list = names~allItems~sortWith(.CaselessComparator~new)
block = .array~new
line = ""
do n over list
  if length(line) + length(n) > 70 then do
    block~append("reserved" line~strip)
    line = ""
  end
  line = line n
end
if line \= "" then block~append("reserved" line~strip)

src = .stream~new(target)~arrayIn
out = .array~new
skipping = .false
done = .false
do l over src
  if skipping then do
    if l~strip~caselessEquals("::END") then do
      out~appendAll(block)
      out~append(l)
      skipping = .false
      done = .true
    end
  end
  else do
    out~append(l)
    if l~strip~upper~space == "::RESOURCE OODRESERVED" then skipping = .true
  end
end
if \done then do
  say "reserved: no ::RESOURCE oodReserved in" target
  return 1
end
st = .stream~new(target)
st~open("write replace")
st~arrayOut(out)
st~close
say "reserved:" list~items "names written to" target
return 0
::requires "ooDialog.cls"
