p = .VarProbe~new
say p~probe
say p~lineOffset
p~setIt(7)
say p~lineOffset
say .VarProbe~new~lineOffset + 1
