/* Error categories and recovery are part of stream fidelity. */
f='definitely_missing_23985.dat'
say 'status-missing='stream(f,'S')
say 'missing-linein='safe('linein',f)
say 'missing-charin='safe('charin',f)
say 'missing-open='safe('open',f)
say 'invalid-query='safe('badquery',f)
say 'create-after-error='stream(f,'C','OPEN WRITE REPLACE')
say 'write-after-error='lineout(f,'RECOVER')
say 'close='stream(f,'C','CLOSE')
say 'read-after-error='linein(f)
say 'final-close='stream(f,'C','CLOSE')
exit 0
safe: procedure
  parse arg op, fn
  signal on syntax name syntaxError
  signal on notready name notreadyError
  select
    when op='linein' then result=linein(fn)
    when op='charin' then result=charin(fn)
    when op='open' then result=stream(fn,'C','OPEN READ')
    otherwise result=stream(fn,'C','QUERY LINE')
  end
  return 'value:' || c2x(result)
syntaxError:
  return 'SYNTAX:' || condition('C') || ':' || rc
notreadyError:
  return 'NOTREADY:' || condition('C') || ':' || condition('D')
