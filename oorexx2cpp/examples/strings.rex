/* Exact string printing and quoted-string escaping. */
who = 'Ada'
say 'Hello,' who
say 'It''s a test.'
say 'Unassigned variable:' missing
if '  hello ' = 'hello' then do
    say 'loose equality works'
end
if 'hello ' \== 'hello' then do
    say 'strict inequality works'
end
