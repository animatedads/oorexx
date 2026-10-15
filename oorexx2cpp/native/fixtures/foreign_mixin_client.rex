a = .A~new('x')
say a~bump a~bump a~name a~count a~kind
b = .B~new
say b~count b~bump b~bump b~bump
c = .C~new('y')
say c~bump c~name
i = .I~new
say i~bump i~bump i~own
d = .D~new
say d~bump d~count
say a~count b~count c~count i~count
say .A~superclasses~makestring("L", ",") .D~superclass
exit
::class I inherit Counter
::method own
  expose count
  return var('COUNT')
