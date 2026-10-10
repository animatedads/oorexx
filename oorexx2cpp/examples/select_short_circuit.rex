/* Later WHEN conditions must never be evaluated after a match. */
select
  when 1 = 1 then say 'first'
  when 1 / 0 = 1 then say 'wrong'
  otherwise say 'wrong default'
end
