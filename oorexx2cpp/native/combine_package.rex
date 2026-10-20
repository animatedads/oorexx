/* rx2cpp: combine a multi-file ooRexx package into one source for the native lane.
   ::REQUIRES 'file.cls' of a file next to the requiring one (or on REXX_PATH) is resolved depth-first,
   dependencies first (parents before subclasses), each file once; those ::REQUIRES lines are removed.
   ::REQUIRES ... LIBRARY, requires of files that cannot be found, and files named in RX2CPP_KEEP_INTERPRETED stay as
   they are (the native lane then decides; a kept file is loaded by the interpreter). Each file's own ::OPTIONS stay at the top of its section only if identical to the first.
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
/* Each file's prolog (its clauses before the first directive) runs when the interpreter loads that file, dependencies
   first. Combined, a prolog would follow the previous file's last routine (and be compiled as part of it, or after its
   RETURN), so each one becomes a routine of its own, RX2CPP_PROLOG_n, its directive on the file's marker line (its lines
   keep their numbers), and the combined package's prolog calls them in load order. */
combined = ''
calls = ''
n = 0
do f over order
  marker = '/* ---- rx2cpp combined: ' || f || ' ---- */'
  if hasProlog(seen[f]) then do
    n += 1
    marker = '::routine RX2CPP_PROLOG_' || n marker
    calls = calls || 'call RX2CPP_PROLOG_' || n || '0a'x
  end
  combined = combined || marker || '0a'x || strip(seen[f], 'T', '0a'x) || '0a'x
end
combined = calls || combined
call stream output, 'c', 'open write replace'
call charout output, combined
call stream output, 'c', 'close'
say order~items
exit 0

/* True when the text has a clause before its first directive (comments and blank lines are not clauses). */
hasProlog: procedure
  use arg text
  i = 1; n = length(text); depth = 0; atStart = .true
  do while i <= n
    c = text~substr(i, 1)
    if depth > 0 then do
      if text~substr(i, 2) == '/*' then do; depth += 1; i += 2; iterate; end
      if text~substr(i, 2) == '*/' then do; depth -= 1; i += 2; iterate; end
      i += 1; iterate
    end
    select
      when text~substr(i, 2) == '/*' then do; depth = 1; i += 2; end
      when text~substr(i, 2) == '--' then do
        e = pos('0a'x, text, i)
        if e = 0 then return .false
        i = e
      end
      when c == '0a'x | c == ';' then do; atStart = .true; i += 1; end
      when c == ' ' | c == '09'x | c == '0d'x then i += 1
      when atStart & text~substr(i, 2) == '::' then return .false   /* the first directive: nothing before it */
      otherwise return .true
    end
  end
  return .false

visit: procedure
  use arg file, seen, order
  if seen~hasIndex(file) then return
  seen[file] = ''
  text = charin(file, 1, chars(file))
  call stream file, 'c', 'close'
  dir = filespec('location', file)
  /* RX2CPP_SOURCE_DIR: where the input file really is (compile_program.sh compiles a copy of the program elsewhere):
     its ::REQUIRES are looked for there first, as the interpreter looks next to the requiring file */
  if order~items == 0 & seen~items == 1 then do
    sourceDir = value('RX2CPP_SOURCE_DIR', , 'ENVIRONMENT')
    if sourceDir \== '' then dir = sourceDir || '/'
  end
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
      /* RX2CPP_KEEP_INTERPRETED="ooTest.frm FileUtils.cls ...": these stay ordinary ::REQUIRES (the interpreter loads them). */
      keep = .false
      do kept1 over value('RX2CPP_KEEP_INTERPRETED', , 'ENVIRONMENT')~makeArray(' ')
        if kept1 \== '' & translate(filespec('name', name)) == translate(kept1) then keep = .true
      end
      if keep then do
        kept = kept || line || '0a'x
        iterate
      end
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
    /* A #! line is only valid as line 1 of a program: blank it in a combined file (line numbering kept). */
    if line~left(2) == '#!' & kept == '' then do
      kept = kept || '0a'x
      iterate
    end
    kept = kept || line || '0a'x
  end
  seen[file] = kept
  order~append(file)
  return
