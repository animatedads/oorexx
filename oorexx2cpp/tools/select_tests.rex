#!/usr/bin/env rexx
/* select_tests.rex: which test scripts a change can affect, from what each test was measured to read.
   Architecture: Tom Dyer (the blast-radius check to cut test time).  Code: Claude (Opus 5.5), 2026-10-30.

   Usage:  rexx tools/select_tests.rex [READS-FILE] < changed-files
     changed-files: one path per line, relative to this directory (oorexx2cpp/), e.g. from
       git diff --name-only --relative BASE
     READS-FILE: default ootest/test_reads.tsv: "test<TAB>file" lines, the tracked files each test script read
       during a full regression (access times reset before each test, read after; tools/record_reads.sh).
   Output, one line each:
     RUN test-script     why (the first changed file it read)
     ALL reason          a changed file the measurement cannot speak for: run the full regression
     NONE                no test read any changed file
     TIME ...            after the RUN lines, when the record has timings: the measured seconds selected and saved
   A changed file is safe to skip only when it was tracked at the measured commit and no test read it.
   A file that was not tracked then (new) gives ALL, as does a change to the test harness itself.
   The full regression stays the merge gate: this is for checks while working. */
parse arg readsFile
if readsFile = '' then readsFile = 'ootest/test_reads.tsv'
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
selected = .directory~new         /* test -> why */
all = ''
do while lines() > 0
  changed = linein()~strip
  if changed = '' then iterate
  if changed~left(11) = 'oorexx2cpp/' then changed = changed~substr(12)
  isScript = (changed~left(12) = 'native/test_' | changed~left(11) = 'tests/test_') & changed~right(3) = '.sh'
  if tests~hasIndex(changed) | isScript then do         /* a test script itself, new or measured */
    if \selected~hasIndex(changed) then selected[changed] = 'changed'
    iterate
  end
  if changed = 'tools/select_tests.rex' | changed = 'tools/record_reads.sh' then do
    all = changed 'is the selector'; iterate
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
