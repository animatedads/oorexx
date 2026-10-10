/* One simple instruction after THEN, ELSE is a separate clause. */
if 2 = 1 then say 'bad'
else say 'yes'
if 2 = 2 then say 'correct'
else say 'bad'
x = 1
if x = 1 then x = x + 2
else x = 99
say x
if 1 = 1 then if 0 = 1 then say 'bad'
else say 'nearest'
