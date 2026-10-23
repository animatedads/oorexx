/* ooRexx: checkUninit counts a pending object again at the next collection: pendingUninits never returns to 0, and
   from then on every activation scans the whole uninit table (MemoryObject::runUninits).
   usage: rexx uninitscan.rex [live objects with UNINIT, default 20000] */
parse arg live .
if live = '' then live = 20000
keep = .array~new
do i = 1 to live; keep~append(.u~new); end        -- a big uninit table (live objects, never collected)
say 'calls before:' calls() 's'
do i = 1 to 1000; .u~new; end                     -- garbage with an UNINIT
-- one built-in method that allocates enough for several collections before it returns (no activation runs between
-- them, so the dead objects are counted again at each collection)
lines = copies('ab' || '0a'x, 3000000)~makeArray('0a'x)
drop lines
say 'uninits run:' .u~count
say 'calls after: ' calls() 's'
say 'calls later: ' calls() 's'
say 'uninits run:' .u~count
exit
calls: procedure
  call time 'r'
  do i = 1 to 100000; call nothing; end
  return format(time('e'), , 2)
nothing: return
::class u
::attribute count class
::method init class
  expose count; count = 0
::method uninit
  self~class~count += 1
