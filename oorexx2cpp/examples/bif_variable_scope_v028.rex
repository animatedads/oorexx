x='outer'
y='top'
stem.='root'
call parent
say x y stem.a
exit 0
parent:
    procedure expose x stem.
    y='private'
    say value('x') value('y') value('stem.')
    say value('x','new') value('y','local')
    call child
    say value('x') value('y')
    return
child:
    procedure expose x
    say value('x') value('y')
    say value('x','child')
    return
