/* String literals that look like the compiler's own variable macros stay what they are (RxHybridMethod~slotLine
   numbers macros in the code only, not text inside C++ literals). */
x = 'RX_VGET("A")'
a = left(x, 8)
say a length(a) c2x(a)
say (a == 'RX_VGET(') (a = 'RX_VGET(') (left(x, 8) == 'RX_VGET(')
b = 'RX_VGET('
say (a == b) (b == 'RX_VGET(') ('RX_VGET(' == b)
say 'RX_VSET("B", 1)' 'RX_VREF("C")' "RX_VTAIL(""D"")" 'x "RX_VGET("' "'" || 'RX_VGET("E")' || "'"
c = 'RX_VREF("' || b || '")'; say c
