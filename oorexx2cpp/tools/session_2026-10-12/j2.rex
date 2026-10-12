d = .directory~new
d['name'] = 'rx2cpp'; d['version'] = 5; d['tags'] = .array~of('a', 'b', 1.5, .nil); d['ok'] = .json~true; d['no'] = .json~false
d['nested'] = .directory~new; d['nested']['k'] = 'v "quoted" \ back'
say .json~toJSON(d)
say .json~new~toJSON(d, .true)
back = .json~fromJSON('{"x": [1, 2, {"y": "zA"}], "n": null, "t": true, "f": 1.5e3, "s": "a\nb"}')
say back['x']~items back['x'][3]['y'] back['f'] (back['n'] == .nil) back['t'] (back['t'] = .true) back['t']~class~id
s = .json~toJSON(back); say s
signal on syntax
x = .json~fromJSON('{"bad": }')
say 'not reached'
syntax: say 'error:' condition('o')~message
