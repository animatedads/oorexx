/* Integrates v0.19 stem lookup and v0.20 control flow. */
points. = 0
do i = 1 to 4
  points.i = i * 2
  select
    when points.i < 4 then say 'small' i
    when points.i < 8 then do
      points.i += 1
      say 'medium' points.i
    end
    otherwise say 'large' points.i
  end
end
say 'stored' points.2 points.3
