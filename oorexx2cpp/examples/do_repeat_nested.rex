/* Counted outer DO and repetition inner DO. */
count = 3
total = 0
do i = 1 to 5
  do count
    total += i
  end
end
say total
say i
