/* Composition: each compound instruction must evaluate RHS and update
   exactly one variable. Other variable values must remain untouched. */
a=4
b=7
a += b * 3
say a b
b -= 2
say a b
a *= (b - 3)
say a b
a /= 2
say a b
