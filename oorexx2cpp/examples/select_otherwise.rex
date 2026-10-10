/* OTHERWISE consists of multiple consecutive instructions. */
a = 9
select
  when a = 1 then say 'wrong'
  when a = 2 then say 'wrong again'
  otherwise
    say 'default'
    a += 3
    say a
end
say 'tail'
