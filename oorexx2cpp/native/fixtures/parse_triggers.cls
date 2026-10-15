/* PARSE templates as the interpreter runs them (RexxTarget): length positions, comma templates, message-term targets. */
::class ParseT public
::method run
  parse value "01A0002CC" with len1 +2 val1 >(len1) len2 +2 val2 >(len2)
  say len1 val1 len2 val2
  parse value 'abcdefghij' with a 3 b +2 c -4 d <2 e >0 f
  say a '|' b '|' c '|' d '|' e '|' f
  parse value 'hello world  again ' with w1 w2 rest
  say '[' || w1 || '][' || w2 || '][' || rest || ']'
  parse value 'a,b,c' with x ',' y ',' z, p q
  say x y z '[' || p || ']'
  parse caseless value 'xAbCy' with pre 'abc' post
  say pre post
  parse value 'k=v' with key '=' val . 1 whole
  say key val whole
  parse value ' - 123 ' with n1
  say n1 + 0
  d = .directory~new; arr = .array~new
  parse value 'one two three' with d~first arr[2] d~third
  say d~first arr[2] d~third
  parse value 'abc' with '' rest2
  say '[' || rest2 || ']'
  parse value 'abcdef' with 1e1 t1 =(2) t2 +1.0 t3
  say '[' || t1 || '][' || t2 || '][' || t3 || ']'
  signal on syntax
  parse value 'abc' with a +(x) b
  return
syntax: say condition('o')~code condition('o')~message
