/* A real ooRexx source program, also accepted by rx2cpp. */
total = 0
do i = 1 to 5
    total = total + i * i
end
say 'sum of squares:' total
say 'after loop i:' i
if total = 55 then do
    say 'calculation verified'
end
else do
    say 'calculation failed'
end
