#!/usr/bin/env rexx
/* select_tests.rex: which test scripts a change can affect, from what each test was measured to read.
   Architecture: Tom Dyer (the blast-radius check to cut test time).  Code: Claude (Opus 5.5), 2026-10-30.

   Usage:  rexx tools/select_tests.rex [READS-FILE [COVERAGE-FILE]] < changed-files
     changed-files: one path per line, relative to this directory (oorexx2cpp/), e.g. from
       git diff --name-only --relative BASE
     and, for C/C++ files, optional lines "LINES file ranges": the lines of file that changed, numbered as at the
       commit the coverage was measured at ("a-b" changed or deleted, "a+" lines inserted after line a).
     READS-FILE: default ootest/test_reads.tsv: "test<TAB>file" lines, the tracked files each test script read
       during a full regression (access times reset before each test, read after; tools/record_reads.sh).
     COVERAGE-FILE: default ootest/test_coverage.tsv (tools/coverage_record.rex): which lines of each C/C++ file
       each test ran. With it and LINES, a changed function selects only the tests that ran it. Every reader of the
       file still runs when a changed line is outside every function, in a constexpr function, or in a function no
       test ran; and a test that reads the file without running any of it (compiles it only, or reads it some other
       way) runs on any change to it, as do the scripts that check the C++ with other compilers (byFunction).
   Output, one line each:
     RUN test-script     why (the first changed file it read)
     ALL reason          a changed file the measurement cannot speak for: run the full regression
     NONE                no test read any changed file
     TIME ...            after the RUN lines, when the record has timings: the measured seconds selected and saved
   A changed file is safe to skip only when it was tracked at the measured commit and no test read it.
   A file that was not tracked then (new) gives ALL, as does a change to the test harness itself.
   The full regression stays the merge gate: this is for checks while working. */
parse arg readsFile covFile .
if readsFile = '' then readsFile = 'ootest/test_reads.tsv'
if covFile = '' then covFile = 'ootest/test_coverage.tsv'
if stream(readsFile, 'C', 'QUERY EXISTS') = '' then do
  say 'ALL no measurement:' readsFile 'is missing'
  return 0
end
readers = .directory~new          /* file -> array of tests that read it */
known = .set~new                  /* files tracked at the measured commit */
tests = .set~new
seconds = .directory~new          /* test -> seconds it took when measured */
do while lines(readsFile) > 0
  line = linein(readsFile)
  if line = '' then iterate
  if line~left(1) = '#' then do
    parse var line '#' key value
    if key = 'tracked' then known~put(value~strip)
    if key = 'test' then tests~put(value~strip)          /* measured, even if it read nothing tracked */
    if key = 'seconds' then do
      parse var value t secs .
      seconds[t] = secs
    end
    iterate
  end
  parse var line test '09'x file
  tests~put(test)
  if \readers~hasIndex(file) then readers[file] = .array~new
  readers[file]~append(test)
end
call stream readsFile, 'C', 'CLOSE'
/* the coverage: function ranges per file, and per file the lines each test ran */
funcs = .directory~new            /* file -> array of .array~of(start, end, constexpr) */
ran = .directory~new              /* file -> directory test -> ranges string ('' = compiled, none ran) */
if stream(covFile, 'C', 'QUERY EXISTS') \= '' then do
  do while lines(covFile) > 0
    line = linein(covFile)
    if line~left(3) = '#F ' then do
      parse var line '#F ' file a b flag .
      if \funcs~hasIndex(file) then funcs[file] = .array~new
      funcs[file]~append(.array~of(a, b, flag = 'constexpr'))
      iterate
    end
    if line = '' | line~left(1) = '#' then iterate
    parse var line test '09'x file '09'x spans
    if \ran~hasIndex(file) then ran[file] = .directory~new
    ran[file][test] = spans
  end
  call stream covFile, 'C', 'CLOSE'
end
selected = .directory~new         /* test -> why */
all = ''
input = .array~new                /* the changed files, in order */
changedLines = .directory~new     /* file -> ranges, from LINES */
do while lines() > 0
  line = linein()~strip
  if line = '' then iterate
  if line~word(1) = 'LINES' then do
    parse var line . file spans .
    if file~left(11) = 'oorexx2cpp/' then file = file~substr(12)
    changedLines[file] = spans
  end
  else input~append(line)
end
do changed over input
  if changed~left(11) = 'oorexx2cpp/' then changed = changed~substr(12)
  isScript = (changed~left(12) = 'native/test_' | changed~left(11) = 'tests/test_') & changed~right(3) = '.sh'
  if tests~hasIndex(changed) | isScript then do         /* a test script itself, new or measured */
    if \selected~hasIndex(changed) then selected[changed] = 'changed'
    iterate
  end
  if changed = 'tools/select_tests.rex' | changed = 'tools/record_reads.sh' |,
     changed = 'tools/coverage_record.rex' | changed~left(15) = 'tools/coverage/' then do
    all = changed 'is the selector'; iterate
  end
  if readers~hasIndex(changed), changedLines~hasIndex(changed), ran~hasIndex(changed) then do
    call byFunction changed, changedLines[changed]
    iterate
  end
  if readers~hasIndex(changed) then do
    do t over readers[changed]
      if \selected~hasIndex(t) then selected[t] = 'reads' changed
    end
    iterate
  end
  if \known~hasIndex(changed) then all = changed 'was not tracked when the reads were measured'
end
if all \= '' then do
  say 'ALL' all
  return 0
end
/* A test script on disk that the measurement does not cover reads unknown files: always run it.
   Paths are relative to the current directory, which must be oorexx2cpp/ (tools/run_selected.sh cds there). */
do pattern over .array~of('native/test_*.sh', 'tests/test_*.sh')
  call SysFileTree pattern, 'found.', 'FO'
  do i = 1 to found.0
    t = pattern~left(pattern~pos('/')) || filespec('name', found.i)
    if \tests~hasIndex(t), \selected~hasIndex(t) then selected[t] = 'not measured'
  end
end
if selected~items = 0 then do
  say 'NONE'
  return 0
end
names = selected~allIndexes~sortWith(.CaselessComparator~new)
do t over names
  say 'RUN' t '   ' selected[t]
end
if seconds~items > 0 then do      /* the measured cost: selected against every measured test */
  chosen = 0; total = 0
  do t over seconds~allIndexes
    total += seconds[t]
    if selected~hasIndex(t) then chosen += seconds[t]
  end
  say 'TIME' names~items 'scripts selected, about' chosen 's of' total 's measured (' ||,
      (total - chosen) 's saved)'
end
return 0

/* byFunction file spans: select by the functions the changed lines are in (the coverage), not by the whole file */
byFunction:
  use arg file, spans
  /* readers that ran none of the file (compiled it only, or read it another way) run on any change to it; so do the
     scripts that check the C++ itself with other compilers or stricter warnings (clang++, -pedantic), which coverage
     cannot see */
  compileChecks = .set~of('native/test_generated_warnings.sh', 'native/test_native_nine_standalone.sh')
  do t over readers[file]
    if \ran[file]~hasIndex(t) then call pick t, 'reads' file '(no coverage of it)'
    else if compileChecks~hasIndex(t) then call pick t, 'checks the C++ of' file '(other compilers, warnings)'
  end
  do t over ran[file]~allIndexes
    if ran[file][t] = '' then call pick t, 'compiles' file '(runs none of it)'
  end
  done = .set~new                 /* functions already handled, "start end" */
  do piece over spans~makeArray(',')
    if piece~right(1) = '+' then do       /* inserted after line a: between a and a+1 */
      a = piece~left(piece~length - 1); first = a; last = a + 1
    end
    else do
      parse var piece first '-' last
      if last = '' then last = first
    end
    do n = max(first, 1) to last
      f = innermost(file, n)
      if f = .nil then do
        call allReaders file, 'reads' file '(line' n 'is outside every function)'
        return
      end
      key = f[1] f[2]
      if done~hasIndex(key) then iterate
      done~put(key)
      if f[3] then do
        call allReaders file, 'reads' file '(lines' f[1]'-'f[2] 'are a constexpr function)'
        return
      end
      runners = 0
      do t over ran[file]~allIndexes
        if overlaps(ran[file][t], f[1], f[2]) then do
          call pick t, 'runs' file':'f[1]'-'f[2]
          runners += 1
        end
      end
      if runners = 0 then do
        call allReaders file, 'reads' file '(no test runs lines' f[1]'-'f[2]')'
        return
      end
    end
  end
  return

innermost: procedure expose funcs   /* the smallest function range of file holding line n, or .nil */
  use arg file, n
  best = .nil
  if \funcs~hasIndex(file) then return .nil
  do f over funcs[file]
    if f[1] <= n, n <= f[2] then
      if best = .nil then best = f
      else if f[2] - f[1] < best[2] - best[1] then best = f
  end
  return best

overlaps: procedure                 /* do the ranges "a-b,c" meet start..end? */
  use arg spans, start, end
  if spans = '' then return .false
  do piece over spans~makeArray(',')
    parse var piece a '-' b
    if b = '' then b = a
    if a <= end, b >= start then return .true
  end
  return .false

allReaders:
  use arg file, why
  do t over readers[file]
    call pick t, why
  end
  return

pick:
  use arg t, why
  if \selected~hasIndex(t) then selected[t] = why
  return
