/* rx2cpp: combine a multi-file ooRexx package into one source for the native lane.
   ::REQUIRES 'file.cls' of a file next to the requiring one (or on REXX_PATH) is resolved depth-first,
   dependencies first (parents before subclasses), each file once; those ::REQUIRES lines are removed.
   ::REQUIRES ... LIBRARY and requires of files that cannot be found stay as they are (the native lane
   then decides). Each file's own ::OPTIONS stay at the top of its section only if identical to the first.
   Usage: rexx combine_package.rex input.cls output.cls
   Prints the number of files combined. */
parse arg input output
if input = '' | output = '' then do
  say 'usage: combine_package.rex input.cls output.cls'
  exit 64
end
seen = .directory~new
order = .array~new
call visit qualify(input), seen, order
combined = ''
do f over order
  combined = combined || '/* ---- rx2cpp combined: ' || f || ' ---- */' || '0a'x || strip(seen[f], 'T', '0a'x) || '0a'x
end
call stream output, 'c', 'open write replace'
call charout output, combined
call stream output, 'c', 'close'
say order~items
exit 0

visit: procedure
  use arg file, seen, order
  if seen~hasIndex(file) then return
  seen[file] = ''
  text = charin(file, 1, chars(file))
  call stream file, 'c', 'close'
  dir = filespec('location', file)
  lines = text~makeArray('0a'x)
  kept = ''
  do line over lines
    parse var line lead rest
    /* LIBRARY is the word after the package name, not a substring of it (NativeLibraryEmitter.cls is a file). */
    after = ''
    if translate(lead) == '::REQUIRES' then do
      parse var rest q 2 name (q) after
      if q \== '"' & q \== "'" then parse var rest name after
    end
    if translate(lead) == '::REQUIRES' & wordpos('LIBRARY', translate(after~translate(' ', ';'))) = 0 then do
      /* RX2CPP_LIBMAP="Compress.cls=compresslib ...": a dependency already built as a native library is required as one. */
      mapped = ''
      do pair over value('RX2CPP_LIBMAP', , 'ENVIRONMENT')~makeArray(' ')
        parse var pair from '=' lib
        if from \== '' & translate(filespec('name', name)) == translate(from) then mapped = lib
      end
      if mapped \== '' then do
        kept = kept || "::requires '" || mapped || "' library" || '0a'x
        iterate
      end
      target = .nil
      if stream(dir || name, 'c', 'query exists') \== '' then target = qualify(dir || name)
      else do
        found = SysSearchPath('REXX_PATH', name)
        if found \== '' then target = qualify(found)
      end
      if target \== .nil then do
        call visit target, seen, order
        kept = kept || '0a'x   /* keep line numbering */
        iterate
      end
    end
    kept = kept || line || '0a'x
  end
  seen[file] = kept
  order~append(file)
  return
