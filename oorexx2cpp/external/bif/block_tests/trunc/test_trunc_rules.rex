/* Run from external/bif source root; distinguish native and rejected routes. */
parse arg fixture expected
if fixture = '' then exit 64
if expected = '' then expected = 'NATIVE_SUBSET'
reader = .BifSourceReader~new
entries = reader~scan(fixture)
if entries~items \= 1 then exit 10
rule = .BifBreadthRouteRule~new
one = entries[1]
if one~name \= 'TRUNC' then exit 11
ir = rule~convert(one)
if expected == 'REJECTED' then do
  if ir \== .nil then exit 12
  say 'TRUNC source signature drift: REJECTED'
  exit 0
end
if ir == .nil then exit 13
if ir~kind \= expected then do
  say 'TRUNC source rule expected' expected 'got' ir~kind
  exit 14
end
say 'TRUNC source rule:' ir~kind
exit 0
::requires 'compiler/BifSourceReader.cls'
::requires 'rules/BifBreadthRouteRule.cls'
