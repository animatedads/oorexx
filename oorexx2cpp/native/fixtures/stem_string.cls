/* A stem in an expression is the Stem object: comparisons go to its default value; its string value comes through STRING with NOSTRING. */
::class StemT public
::method run
  v207.='ab'
  v207.1='cd'
  call sub0207 v207., v207.1
  say 'result' result
  return
sub0207:
  say (arg(1) == 'ab')
  return "ARG"(1)||"ARG"(2)
::method trapped
  signal on nostring
  v207.='ab'
  say 'concat' v207. || 'x'
  return
nostring: say 'NOSTRING' condition('d') sigl
