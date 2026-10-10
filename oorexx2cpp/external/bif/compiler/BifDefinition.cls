::class BifDefinition public
::method init
  expose name line lines minArg maxArg
  use arg name, line, lines, minArg, maxArg
::attribute name get
::attribute line get
::attribute lines get
::attribute minArg get
::attribute maxArg get
::method joined
  expose lines
  s = ''
  do v over lines
    s = s || v || '0a'x
  end
  return s
