/* Named LEAVE targeting outer LOOP control from nested counted DO */
a = .Array~of(10, 20, 30)
count = 0
loop item over a
  do i = 1 to 3
    count += 1
    if i = 2 then leave item
  end
end
say count
say item
