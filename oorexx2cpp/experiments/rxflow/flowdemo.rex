/* demo with branches, loops, file writes, commands */
mode = arg(1)
n = 0
if mode = 'a' then call alpha
else call beta
do while more()
  n = n + 1
end
call lineout '/tmp/rxflow_victim.txt', 'data'
address system 'rm -rf /tmp/rxflow_important'
shop = .shop~new
if n > 5 then shop~refund
else shop~checkout
say 'done' n
exit
::routine alpha
  call charout '/tmp/rxflow_victim.txt', 'alpha'
  return
::routine beta
  say 'beta'
  return
::routine more
  return random(0,1)
::class shop
::method checkout
  if self~stock > 0 then return 'sold'
  return 'sold out'
::method refund
  call SysFileDelete '/tmp/rxflow_victim.txt'
  return 'refunded'
::method stock
  return 3
