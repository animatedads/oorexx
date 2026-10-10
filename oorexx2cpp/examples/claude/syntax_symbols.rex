/* ! and ? are symbol characters */
ok? = 'yes'
!flag = 'on'
host.!family = 'AF_INET'
say ok? !flag host.!family
stem.? = 3
say stem.?
/* THEN / ELSE followed by a line break */
do i = 1 to 2
  if i = 1 then -- comment
    say 'one'
  else
    say 'other'
end
