/* Stable transport-neutral IR for this BIF subset. All fields are source-derived
   except qualified native backend boundary and acceptance policy. */
::class BifIR public
::method init
  expose name line minArg maxArg kind method evidence argMeta callShape
  use arg name, line, minArg, maxArg, kind, method, evidence, argMeta, callShape
::attribute name get
::attribute line get
::attribute minArg get
::attribute maxArg get
::attribute kind get
::attribute method get
::attribute evidence get
::attribute argMeta get
::attribute callShape get
