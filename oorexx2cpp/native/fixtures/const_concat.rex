/* concatenation of literals folded into one literal when compiled: the same characters as the interpreter joins */
x = 'with' 2 'args'; say '[' || x || ']'
say substr(1234"5678",6,2) '(This is the second)'1''1
a = 'ab ' 'cd'; b = 'p'||'q'||'r'; c = 1.0''7; d = 1e3 'y'; e = 'é' || "z"
say '[' || a || '][' || b || '][' || c || '][' || d || '][' || e || ']'
say length('a' || '') length('' '') 'q'"w"
say 'a' 'b' || 'c'"d" 3 4 5 '' '' '!'
