/* Audit only: scans ooTest source without executing its tests.
   Intentionally coarse markers: these are search hints, not grammar coverage.
   One loadable class owns this source-scan rule set. */
::class OoTestGroupScanner public
::method features class
  return .array~of('MESSAGE', 'DIRECTIVE_CLASS', 'DIRECTIVE_REQUIRES', 'PARSE', 'SELECT', 'SIGNAL', 'DO', 'CALL', 'USE_ARG', 'EXPOSE', 'NUMERIC', 'INTERPRET', 'ADDRESS', 'RAISE', 'FORWARD', 'ARRAY', 'STEM', 'BIF')

::method scan
  use strict arg path
  features = .OoTestGroupScanner~features
  hits = .directory~new
  do feature over features
    hits[feature] = 0
  end
  testCount = 0
  methodCount = 0
  lineCount = 0
  do while lines(path) > 0
    raw = linein(path)
    lineCount += 1
    line = translate(strip(raw))
    -- Skip obvious comments.  Inline comments and literal strings still count.
    if line = '' | left(line, 2) = '--' | left(line, 2) = '/*' | left(line, 1) = '*' then iterate
    if left(line, 8) = '::METHOD' then do
      methodCount += 1
      header = strip(substr(line, 9))
      if left(header, 4) = 'TEST' | left(header, 5) = '"TEST' | left(header, 5) = "'TEST" then testCount += 1
    end
    if pos('~', line) > 0 then hits['MESSAGE'] += 1
    if left(line, 7) = '::CLASS' then hits['DIRECTIVE_CLASS'] += 1
    if left(line, 10) = '::REQUIRES' then hits['DIRECTIVE_REQUIRES'] += 1
    if left(line, 6) = 'PARSE ' then hits['PARSE'] += 1
    if left(line, 7) = 'SELECT ' | line = 'SELECT' then hits['SELECT'] += 1
    if left(line, 7) = 'SIGNAL ' then hits['SIGNAL'] += 1
    if left(line, 3) = 'DO ' | line = 'DO' then hits['DO'] += 1
    if left(line, 5) = 'CALL ' then hits['CALL'] += 1
    if left(line, 8) = 'USE ARG ' | left(line, 11) = 'USE STRICT ' then hits['USE_ARG'] += 1
    if left(line, 7) = 'EXPOSE ' then hits['EXPOSE'] += 1
    if left(line, 8) = 'NUMERIC ' then hits['NUMERIC'] += 1
    if left(line, 10) = 'INTERPRET ' then hits['INTERPRET'] += 1
    if left(line, 8) = 'ADDRESS ' then hits['ADDRESS'] += 1
    if left(line, 6) = 'RAISE ' then hits['RAISE'] += 1
    if left(line, 8) = 'FORWARD ' | line = 'FORWARD' then hits['FORWARD'] += 1
    if pos('.ARRAY', line) > 0 then hits['ARRAY'] += 1
    if pos('.0', line) > 0 | pos('.1', line) > 0 then hits['STEM'] += 1
    if pos('ABS(',line) > 0 | pos('SUBSTR(',line) > 0 | pos('STREAM(',line) > 0 then hits['BIF'] += 1
  end
  call stream path, 'C', 'CLOSE'
  statsObject = .directory~new
  statsObject['TESTS'] = testCount
  statsObject['METHODS'] = methodCount
  statsObject['LINES'] = lineCount
  statsObject['HITS'] = hits
  return statsObject
