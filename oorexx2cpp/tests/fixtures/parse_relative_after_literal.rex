s = 'abcdefgh'; i = 5; p = 2
parse value s with =(p) a +(i - p) b
say a b
parse value s with 'c' x +(1+1) y
say x y
parse value 'abcdefghij' with 'd' x1 -2 y1 'h' z1 +1 w1
say '<'x1'><'y1'><'z1'><'w1'>'
parse value 'a,b,c' with p ',' q ',' r
say p q r
parse value 'xyz' with 'q' m1 +1 n1
say '<'m1'><'n1'>'
