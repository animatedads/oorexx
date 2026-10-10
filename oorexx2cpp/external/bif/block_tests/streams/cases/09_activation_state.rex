/* Are open cursors shared across routine/PROCEDURE activation boundaries? */
f='activation.dat'
say 'create='stream(f,'C','OPEN WRITE REPLACE')
say 'firstwrite='lineout(f,'ONE')
say 'secondwrite='lineout(f,'TWO')
say 'thirdwrite='lineout(f,'THREE')
say 'close1='stream(f,'C','CLOSE')
say 'parent-open='stream(f,'C','OPEN READ')
say 'parent-first='linein(f)
say 'nested-procedure='nested(f)
say 'parent-last='linein(f)
say 'parent-eof='c2x(linein(f))
say 'parent-state='stream(f,'S')
say 'parent-close='stream(f,'C','CLOSE')
exit 0
nested: procedure
    use arg fname
    return linein(fname)
