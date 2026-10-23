# Rexx Parser benchmark and end-to-end check

`pbench2.rex` (Josep Maria Blasco, 2026-10-23) parses the Rexx Parser's own sources (Rexx.Parser.cls and
parser/*.cls) and counts the elements. Put it in the bin/ directory of Rexx-Parser-latest.zip and run from there.

Interpreted:

```
rexx pbench2.rex 3
```

Compiled (first argument: passes; a second argument writes one line per element there before timing):

```
oorexx2cpp/native/compile_program.sh pbench2.rex OUT
LD_LIBRARY_PATH=OUT rexx OUT/pbench2.rex 1 dump.comp
rexx pbench2.rex 1 dump.interp
cmp dump.interp dump.comp
```

The two dumps must be identical (class, category, from, to and value of every element).

## Results

| Date, commit | Measured by | Interpreted | Compiled | Notes |
|---|---|---|---|---|
| 2026-10-23, d9a3834 | Claude (rx2cpp CI machine, idle) | dump pass 40.8 s; 3 passes 127.6 s | dump pass 19.3 s; 3 passes 55.4 s (2.3x) | dumps identical; 107k crossings |
| 2026-10-23, ca25535 | Josep Maria Blasco (his machine) | level | level | dumps identical over 171,372 elements; 114,327 crossings |

Crossings are calls between compiled code and the interpreter (RX2CPP_BIF_STATS=1 reports them).
