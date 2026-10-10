/* VALUE-ONLY ooRexx BIF chainback. Runs in a NEW activation.
   Do not add ARG, TRACE, VALUE, STREAM, QUEUED, TIME, DATE, RANDOM, etc.
   All execution is by name from an internal whitelist; no user-supplied source. */
/* Numeric envelope precedes the function name. A new routine activation
   starts with its own numeric defaults; always apply caller snapshot here. */
parse arg numericDigits, numericFuzz, numericForm, bif
if datatype(numericDigits,'W') == 0 | datatype(numericFuzz,'W') == 0 then,
    raise syntax 40.900 array ('numeric context absent or invalid')
if numericDigits < 1 | numericFuzz < 0 | numericFuzz >= numericDigits then,
    raise syntax 40.900 array ('numeric context out of range')
if wordpos(numericForm,'SCIENTIFIC ENGINEERING') == 0 then,
    raise syntax 40.900 array ('numeric form unsupported')
/* Numerics directives are assembled ONLY from checked digits and form. */
interpret 'numeric digits ' || numericDigits
interpret 'numeric fuzz ' || numericFuzz
interpret 'numeric form ' || numericForm
safeNames = 'C2D TRUNC X2D D2X D2C TRANSLATE VERIFY DATATYPE SIGN FORMAT MAX MIN XRANGE USERID ERRORTEXT QUALIFY'
if wordpos(bif,safeNames) == 0 then raise syntax 40.900 array ('BIF cannot run detached:' bif)
source = 'result = ' || bif || '('
do j = 5 to arg()
  if j > 5 then source = source || ','
  if arg(j,'E') then do
    variableName = 'p' || j
    call value variableName, arg(j)
    source = source || variableName
  end
end
source = source || ')'
interpret source
return result
