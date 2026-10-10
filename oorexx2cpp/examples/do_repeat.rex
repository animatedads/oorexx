/* Derived from the repetition DO form used in shipped rexxcps.rex. */
count = 4
n = 0
do count
  n += 2
  count = 1
end
say n
say count
count = 0
do count
  say 'never'
end
say 'done'
