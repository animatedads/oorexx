s = 'This is an awfully boring program'
p0 = 'b'
parse var s before (p0) after
say before
say after
s = 'x*y*z'
p0 = '*'
parse var s a (p0) b (p0) c
say a
say b
say c
