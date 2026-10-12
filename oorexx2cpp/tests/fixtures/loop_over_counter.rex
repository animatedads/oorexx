a = .array~of('x','y','z')
do counter c v over a
  say c v
end
say c
do label outer counter n w over a; if n = 2 then leave outer; end
say n w
