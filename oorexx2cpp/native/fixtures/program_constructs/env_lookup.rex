/* environment symbols: looked up each time, the same object is the same value */
say .xyzzy
.local['XYZZY'] = 'one'
say .xyzzy
.local['XYZZY'] = 'two'
say .xyzzy
d = .directory~new
.local['XYZZY'] = d
d['A'] = 1
say .xyzzy~class~id .xyzzy['A'] (.xyzzy == d)
d['A'] = 2
say .xyzzy['A']
.local~remove('XYZZY')
say .xyzzy
.environment['XYZZY'] = 'global'
say .xyzzy
.local['XYZZY'] = 'local wins'
say .xyzzy
.local['XYZZY'] = .nil
say .xyzzy~isNil
.context~package~local['XYZZY'] = 'package local'
say .xyzzy
do i = 1 to 3
  .local['CNT'] = i
  say .cnt
end
say .array~new(2)~size .string~id
mb = .mutablebuffer~new('mb')
.local['XYZZY2'] = mb
mb~append('!')
say .xyzzy2 .xyzzy2~class~id
