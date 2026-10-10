w = .Widget~new
say 'unset' w~both w~readOnly w~inspectSetter
w~both = 'value1'
w~writeOnly = 'value2'
say 'set' w~both w~inspectSetter
say 'get' w~initialiseGetter('value3') w~readOnly
say 'class' .Widget~TAG .Widget~NUMBER .Widget~BARE
say 'instance' w~TAG w~NUMBER w~BARE
say 'quote' w~TAG
say 'empty' length(w~EMPTY)
say 'symbol' .Widget~SYMBOL w~SYMBOL
say 'methods' w~hasMethod('BOTH') w~hasMethod('BOTH=') w~hasMethod('READONLY') w~hasMethod('READONLY=') w~hasMethod('WRITEONLY') w~hasMethod('WRITEONLY=')
::requires 'rx2cpp_attrmodeconstant' library
