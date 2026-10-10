/* From the official ooTest 4.2 SELECT.testGroup test_1 grammar: separators
   between WHEN/condition/THEN, with a normal counted DO around SELECT. */
do i = 3 to 1 by -1
  select; when i=1; then; r1='1'; when i=2; then; r2='2'; otherwise; r3='3'; end
end
say r1 r2 r3
