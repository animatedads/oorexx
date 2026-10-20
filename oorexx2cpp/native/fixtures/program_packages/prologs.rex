/* the prologs of required packages run in load order (Josep Maria Blasco, case 2) */
say "flagB:" .flagB "order:" .order helperA() helperB() helperC()
::requires "pa.cls"
::requires "pb.cls"
