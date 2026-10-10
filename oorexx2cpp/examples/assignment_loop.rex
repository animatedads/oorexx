/* Exercise compound assignment inside DO UNTIL and IF without changes
   to the other independently loaded statement classes. */
total=0
counter=0
do until counter = 6
  counter += 1
  if counter > 2 then total += counter
end
say counter total
