t = .DTest~new
d = t~build
say d~items d['k5'] d['nul' || '00'x || 'key']
say d~allIndexes~makestring('L', ',')
say t~basics
say t~order
say t~loop
say t~remove
say t~unknown
say t~sized
