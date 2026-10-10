/* ooRexx-written census of supplied ooTest testGroups.  Reads a manifest of
   source filenames, scans without executing, emits a TSV with approximate
   syntactic markers to drive feature triage and future per-method extraction. */
parse arg fileList outfile
if fileList = '' | outfile = '' then do
  say 'Usage: rexx inventory.rex manifest.list inventory.tsv'
  exit 64
end
if stream(fileList, 'C', 'QUERY EXISTS') = '' then do
  say 'Missing testGroup manifest:' fileList
  exit 66
end
scanner = .OoTestGroupScanner~new
features = .OoTestGroupScanner~features
tab = '09'x
header = 'path' || tab || 'test_methods_heuristic' || tab || 'all_methods' || tab || 'lines'
do item over features
  header = header || tab || item
end
records = .array~of(header)
totalMethods = 0
totalTests = 0
files = 0
sums = .directory~new
do item over features
  sums[item] = 0
end
do while lines(fileList) > 0
  path = strip(linein(fileList))
  if path = '' then iterate
  stats = scanner~scan(path)
  files += 1
  totalTests += stats['TESTS']
  totalMethods += stats['METHODS']
  record = path || tab || stats['TESTS'] || tab || stats['METHODS'] || tab || stats['LINES']
  do item over features
    count = stats['HITS'][item]
    sums[item] += count
    record = record || tab || count
  end
  records~append(record)
end
call stream fileList, 'C', 'CLOSE'
call stream outfile, 'C', 'OPEN WRITE REPLACE'
do record over records
  call lineout outfile, record
end
call stream outfile, 'C', 'CLOSE'
say 'ooTest group files indexed:' files
say '::method declarations:' totalMethods
say 'test-prefixed methods (heuristic):' totalTests
say 'Marker lines (not semantic coverage or unique features):'
do item over features
  say '  ' left(item, 19) sums[item]
end
exit 0
::requires 'OoTestGroupScanner.cls'
