o = .Re~new(0)
say "a:" o~a
say "tag after:" o~tag
s = .Sub~new(0)
say "override:" s~a
c = .Re~new(0)
r = .Runner~new
msgs = .array~new
do 4; msgs~append(r~start("RUN", c, 2500)); end
do m over msgs; m~result; end
say "bump total (expect 10000):" c~count
signal on syntax name caught
say "NO ERROR" .Re~new(0)~bad
exit
caught:
say "bad ->" condition('O')~code
::requires 'rx2cpp_selfsend' library
::class Sub subclass Re
::method b
  return 7
::class Runner
::method run unguarded
  use arg c, k
  do k; c~bump; end
  return 0
