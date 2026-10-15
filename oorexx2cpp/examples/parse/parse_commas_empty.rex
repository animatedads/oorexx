/* An empty string pattern matches at the end; a comma starts the next template on the null string. */
s = 'abc def'
parse var s a '' b
say '[' || a || '][' || b || ']'
parse value 'a b' with x, y
say '[' || x || '][' || y || ']'
parse source sys ., z
say '[' || z || ']'
