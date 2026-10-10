say symbol('missing') var('missing') value('missing')
x='first'
say symbol('x') var('x') value('x')
say value('x','second')
say value('x')
say symbol('123') var('123') value('123')
say symbol('x+') var('x+')
stem.='base'
i='hello'
stem.i='part'
say symbol('stem.i') var('stem.i') value('stem.i')
say value('stem.i','changed')
say value('stem.hello')
say symbol('stem.') var('stem.') value('stem.')
