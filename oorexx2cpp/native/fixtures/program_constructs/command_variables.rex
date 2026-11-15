/* A command environment that reads and sets the caller's variables (HOSTEMU's EXECIO ... STEM, through the variable
   pool), from compiled code: the stem written out (DISKW) is the compiled stem, the stem read in (DISKR) arrives in the
   compiled variables, new or already there, in the program, an internal procedure and a method; a shell command
   carries nothing. Before: the handler worked on a helper's variables and the compiled stem stayed unset (bug #1793
   repro). Output identical to the interpreter. Claude (Opus 5.5), 2026-11-15. */
address system 'rm -f cv_a.txt cv_b.txt'
out.0 = 3; out.1 = 'first line'; out.2 = 'second'; out.3 = 'third and last'
address hostemu
'execio * diskw cv_a.txt (finis stem out.'
say 'diskw rc' rc
'execio * diskr cv_a.txt (finis stem in.'
say 'diskr rc' rc in.0 in.1 '|' in.3
old.0 = 9; old.7 = 'stays?'
'execio * diskr cv_a.txt (finis stem old.'
say old.0 old.1 old.7
'execio 1 diskr cv_a.txt (finis stem one.'
say one.0 one.1
say viaProc() .reader~new~read
address system 'echo shell' with output stem sh.
say sh.0 sh.1
address system 'rm -f cv_a.txt cv_b.txt'
exit
viaProc: procedure
  w.0 = 2; w.1 = 'proc 1'; w.2 = 'proc 2'
  address hostemu 'execio * diskw cv_b.txt (finis stem w.'
  address hostemu 'execio * diskr cv_b.txt (finis stem r.'
  return r.0 r.2
::class reader
::method read
  address hostemu 'execio * diskr cv_a.txt (finis stem m.'
  return m.0 m.2
::requires 'hostemu' LIBRARY
