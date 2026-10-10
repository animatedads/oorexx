/* A DO UNTIL instruction is also valid as a THEN branch. */
i = 0
if 1 = 1 then do until i = 2
  i = i + 1
end
say i
if 1 = 0 then do until i = 3
  i = i + 1
end
else say 'skipped'
