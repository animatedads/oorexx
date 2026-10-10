i = 0
do until i = 3
  i = i + 1
  j = 0
  do until j = 2
    j = j + 1
    if j = 1 then say i j
  end
  if i = 2 then say 'middle'
end
say 'finished'
