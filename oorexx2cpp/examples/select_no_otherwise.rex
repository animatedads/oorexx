/* Valid SELECT without OTHERWISE when one WHEN is true. */
value = 5
select
  when value < 0 then say 'negative'
  when value = 5 then say 'five'
end
say 'after'
