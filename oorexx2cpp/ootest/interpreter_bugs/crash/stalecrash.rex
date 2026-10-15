signal on syntax
.Probe~staleThenGc('stalecrashq', 4)
exit
syntax: say 'SYNTAX' condition('o')~code
::class Probe
::method staleThenGc class external 'LIBRARY stalecrash stale_then_gc'
