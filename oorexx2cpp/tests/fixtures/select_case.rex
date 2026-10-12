do x over .array~of('a', 'b', 'c ', 1.0)
  select case x
    when 'b', 'a' then say x 'ab'
    when 1 then say x 'one'
    otherwise say x 'other'
  end
end
