/* DO name OVER collection is the LOOP name OVER form */
a = .array~new
a~append('p'); a~append('q')
do e over a
  say e
end
loop f over a
  say f
end
