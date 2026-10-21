do v over (0, 1, 5, 127, 128, 255, 256, 65535, 65536, -1, -128, -129, -256, -65536, '007', '-0', 123456789, -123456789)
  do n over (0, 1, 2, 3, 4)
    say v n c2x(d2c(v, n)) d2x(v, n)
  end
end
numeric digits 3
signal on syntax
say c2x(d2c(1234, 2))
exit
syntax: say condition('o')~code
