/* Source-derived admission must be fail-closed on upstream changes. */
parse arg fixture expected
if fixture == '' then exit 64
reader = .BifSourceReader~new
definitions = reader~scan(fixture)
if definitions~items \= 1 then exit 10
one = definitions[1]
if one~name \= 'X2D' then exit 11
result = .BifBreadthRouteRule~new~convert(one)
if expected == 'REJECTED' then do
  if result \== .nil then exit 12
  say 'X2D changed arity: REJECTED'
  exit 0
end
if result == .nil then exit 13
if result~kind \= expected then exit 14
say 'X2D source route:' expected
exit 0
::requires 'compiler/BifSourceReader.cls'
::requires 'rules/BifBreadthRouteRule.cls'
