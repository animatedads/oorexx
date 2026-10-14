/* PARSE with an empty template: the source is evaluated (and read), nothing is assigned. */
s = 'a b c'
parse value 3 with
parse var s
parse source
parse version
parse arg
say 'empty templates:' s
x = 'unchanged'
parse value 'y z' with
say x
