vals = '1.1 1.10 2.2 -0.5 .5 5. 0.05 123456789 99999999.9 1e3 0.000000001 1.000000001 -3.25 100 0.1 7 +4.5 0.0 12345.678'
do i = 1 to words(vals)
  do j = 1 to words(vals)
    a = word(vals,i); b = word(vals,j)
    say a b (a+b) (a-b) (a*b) (a=b) (a<b) (a>=b)
  end
end
numeric digits 5
say 1.1*1.1 123.45+0.001 9999.9+0.1 1.2345*1.2345 0.0001-1
s = 'abc'; say (s = 'abc  ') (s < 'abd') (' x' = 'x') ('a'||'01'x < 'a')
numeric digits 4
say (1000 = 999.9) (1000 > 999.9) (1.5 < 1.25) (0.1 = 0.10) (12.5 >= 12.50)
numeric digits 9
say (1.1 > 1.10) (2.2 = 2.20) (-0.5 < 0.5) (100000000 = 99999999.5)
