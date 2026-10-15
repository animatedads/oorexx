/* Message instructions whose first term is not a plain symbol (LanguageParser::nextInstruction: parseMessageTerm before
   keywords): f(...)~m, 'literal'~m, (expr)~m, keyword(...)~m (a routine call); RESULT set, nothing run as a command; an empty index list (v.[]). */
::class MessageTerms public
::method run
  a = .array~new
  drop result
  mk(a)~append('one')
  say a~items var('RESULT') result
  'abc'~reverse
  say result
  (a)~append('two')
  say a~items result
  signal on syntax name notRoutine
  say('x')~length                    -- a call of a routine SAY, not the SAY instruction
notRoutine:
  say condition('O')~code
  mk(a)~~append('three')~append('four')
  say a~items a~makestring('L', ',')
  v. = 'dflt'
  v.7 = 'seven'
  say v.[] v.[7] v.[] || '!'          -- [] with no index: the stem's default value
  return 'ok'
mk: return arg(1)
