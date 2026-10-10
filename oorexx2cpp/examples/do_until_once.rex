/* A post-tested loop must run even when UNTIL is already true. */
i = 0
do until i = 0
  say 'once'
end
say i
