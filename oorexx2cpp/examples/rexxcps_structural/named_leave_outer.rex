x = 0
do first = 1 to 5
  do second = 1 to 5
    if second = 3 then leave first
    x += 1
  end second
end first
say x
say first
say second
