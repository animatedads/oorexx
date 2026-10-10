text = 'red green blue'
do i = 1 to 3
  parse var text first second remainder
  select
    when i = 2 then say second
    otherwise say first
  end
end
say remainder
