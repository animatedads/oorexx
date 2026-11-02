#!/usr/bin/env rexx
/* coverage_record.rex COV-DIR SOURCE-ROOT COMMIT [OUT]: build ootest/test_coverage.tsv from tools/record_coverage.sh.
   Architecture: Tom Dyer (the blast-radius check).  Code: Claude (Opus 5.5), 2026-11-02.

   COV-DIR: the <script>.cov files ("L file line" for a line that ran, "F file start end" for a function gcov saw).
   SOURCE-ROOT: oorexx2cpp/ at COMMIT (the snapshot that ran), read to mark constexpr functions.
   Output lines:
     # measured at COMMIT ...
     #F file start end [constexpr]     every function range any test saw, once
     test<TAB>file<TAB>lines            the lines of file the test ran, as ranges "a-b,c" (empty: compiled, none ran)
   A constexpr function can give its results while compiling, where no line "runs": tools/select_tests.rex treats a
   change in one like a change outside every function (every reader of the file runs). */
parse arg covDir srcRoot commit out
if commit = '' then do
  say 'usage: rexx tools/coverage_record.rex COV-DIR SOURCE-ROOT COMMIT [OUT]'
  return 64
end
if out = '' then out = 'ootest/test_coverage.tsv'
funcs = .directory~new                /* "file start end" -> 1 */
call SysFileTree covDir'/*.cov', 'covs.', 'FO'
if covs.0 = 0 then do
  say 'no .cov files in' covDir
  return 1
end
if stream(out, 'C', 'QUERY EXISTS') \= '' then call SysFileDelete out
rows = .array~new
do i = 1 to covs.0
  name = filespec('name', covs.i)
  script = name~left(name~length - 4)            /* without .cov */
  if stream(srcRoot'/native/'script, 'C', 'QUERY EXISTS') \= '' then test = 'native/'script
  else if stream(srcRoot'/tests/'script, 'C', 'QUERY EXISTS') \= '' then test = 'tests/'script
  else iterate
  ran = .directory~new                /* file -> array of line numbers that ran */
  seen = .set~new                     /* files it compiled (a function range of them) */
  do while lines(covs.i) > 0
    parse value linein(covs.i) with kind file a b .
    if kind = 'F' then do
      funcs[file a b] = 1
      seen~put(file)
    end
    else if kind = 'L' then do
      if \ran~hasIndex(file) then ran[file] = .array~new
      ran[file]~append(a)
    end
  end
  call stream covs.i, 'C', 'CLOSE'
  do file over seen
    if ran~hasIndex(file) then rows~append(test'09'x || file'09'x || ranges(ran[file]))
    else rows~append(test'09'x || file'09'x)
  end
  do file over ran~allIndexes
    if \seen~hasIndex(file) then rows~append(test'09'x || file'09'x || ranges(ran[file]))
  end
end
call lineout out, '# measured at' commit': the lines of C/C++ files each test script ran (tools/record_coverage.sh, ' ||,
  'tools/coverage_record.rex)'
sources = .directory~new              /* file -> its lines, read once */
nfuncs = 0
do key over funcs~allIndexes~sort
  parse var key file a b
  if \sources~hasIndex(file) then sources[file] = readLines(srcRoot'/'file)
  text = sources[file]
  mark = ''
  if a <= text~items then if text[a]~pos('constexpr') > 0 then mark = ' constexpr'
  call lineout out, '#F' file a b || mark
  nfuncs += 1
end
do r over rows~sort
  call lineout out, r
end
call lineout out
say rows~items 'test and file rows,' nfuncs 'function ranges,' covs.0 'scripts:' out
return 0

ranges: procedure          /* sorted line numbers as "a-b,c,d-e" */
  use arg nums
  nums = nums~sortWith(.NumericComparator~new)
  s = ''; first = ''; last = ''
  do n over nums
    if first = '' then do; first = n; last = n; iterate; end
    if n = last then iterate
    if n = last + 1 then do; last = n; iterate; end
    s = s || piece(first, last)','
    first = n; last = n
  end
  if first \= '' then s = s || piece(first, last)
  return s

piece: procedure
  use arg a, b
  if a = b then return a
  return a || '-' || b

readLines: procedure
  use arg path
  lines = .array~new
  if stream(path, 'C', 'QUERY EXISTS') = '' then return lines
  do while lines(path) > 0
    lines~append(linein(path))
  end
  call stream path, 'C', 'CLOSE'
  return lines
