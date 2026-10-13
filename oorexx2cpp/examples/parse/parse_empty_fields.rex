/* String patterns found right at the cursor delimit empty fields; positional patterns behind the cursor take the rest. */
s = '4D63::;5450:5451::::x'
parse var s f1 ':' f2 ':' f3 ';' f4 ':' f5 ':' f6 ':' f7 ':' f8 ':' f9
say '[' || f1 || '] [' || f2 || '] [' || f3 || '] [' || f4 || '] [' || f5 || '] [' || f6 || '] [' || f7 || '] [' || f8 || '] [' || f9 || ']'
parse value 'a;;b;' with p1 ';' p2 ';' p3 ';' p4
say '[' || p1 || '] [' || p2 || '] [' || p3 || '] [' || p4 || ']'
parse value 'abcdef' with u1 3 u2 3 u3
say '[' || u1 || '] [' || u2 || '] [' || u3 || ']'
parse value 'abcdef' with v1 'c' v2 'c' v3
say '[' || v1 || '] [' || v2 || '] [' || v3 || ']'
