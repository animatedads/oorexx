/* Nested SELECT in WHEN DO and a separate IF/THEN nested branch. */
x = 1
select
  when x = 1 then do
    select
      when x = 2 then say 'wrong nested'
      when x = 1 then do
        if x = 1 then say 'nested correct'
      end
      otherwise say 'wrong default'
    end
    say 'outer block end'
  end
  otherwise say 'wrong outer'
end
say 'finished'
