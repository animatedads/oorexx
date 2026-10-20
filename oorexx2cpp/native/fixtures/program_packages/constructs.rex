/* constructs found compiling the Rexx Parser (Josep Maria Blasco, 2026-10-20) */
do = .directory~new
DO~Lambda.Do.Block = 'block'                      -- a keyword symbol as a message receiver
say = .array~new; SAY[1] = 'first'; say say[1] do~lambda.do.block
a = .array~new; a[1] = 3, 4; say a[1]~items a[1][2]          -- a comma list assigned through []=
d = .directory~new; d~x = 5, , 7; say d~x~items d~x[3]        -- and through an attribute
signal "Over There"
say 'skipped'
"Over There": say 'string label reached'
signal on syntax name "trap me"
say 1 / 0
"trap me": say 'string label trap' rc
o = .child~new
say o~hello (o < 2) (o \< 2)
o~fill; say o~show
say o~opts.[1] o~opts.[2]
exit
::class child subclass parent                      -- a parent defined further on
::method hello; return 'child of' self~base
::method "<"; return self ~ "<" : super(arg(1))    -- a string selector to SELF with :SUPER
::method "\<"; return self ~ "\<" : super(arg(1))
::method fill
  use local i tmp
  tmp = 'local'
  count = 0
  do i = 1 to 3; count = count + i; list.i = i * 10; end
  name = 'filled'
  if count > 5 then flag = 1
::method show
  expose count name list. flag
  return count name list.2 list.3 flag symbol('I') symbol('TMP')
::attribute opts. get
::method init
  expose opts.
  opts.1 = 'one'; opts.2 = 'two'
::class parent
::method base; return 'parent'
::method "<"; return 'lt' arg(1)
::method "\<"; return 'nlt' arg(1)
