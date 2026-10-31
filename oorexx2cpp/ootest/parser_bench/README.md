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
| 2026-10-26, e3d8d00 (main) | Claude (rx2cpp CI machine, idle) | dump pass 50.5 s; 3 passes 144.8 s | dump pass 17.7 s; 3 passes 54.1 s (2.68x) | dumps identical over 162,260 elements; 79,398 crossings |
| 2026-10-27, 59d2019 (wip) | Claude (rx2cpp CI machine, idle) | 3 passes 114 s | 3 passes 39.0 / 39.8 s (2.9x) | dumps identical; cycle leak closed (peak 315 MB); 65.6 G instructions a pass (callgrind) |
| 2026-10-27, d43c058 (main, merge of 59d2019) | Claude (rx2cpp CI machine, idle) | dump pass 41.0 s; 3 passes 117.5 s | dump pass 12.1 s; 3 passes 38.0 s (3.09x) | merge gate; dumps identical over 162,260 elements; 71,087 trips a pass |
| 2026-10-28, 35f3315 (main, merge of 17dc90f) | Claude (rx2cpp CI machine after a container restart: a slower host, compare the ratio) | dump pass 63.0 s; 3 passes 193.5 s | dump pass 18.5 s; 3 passes 54.2 s (3.57x) | merge gate; dumps identical; 71,087 trips a pass |
| 2026-10-28, 9850473 (main, merge of 642b413) | Claude (the slower host; compare the ratio) | dump pass 72.5 s; 3 passes 236.7 s | dump pass 21.2 s; 3 passes 67.2 s (3.52x) | merge gate; dumps identical; 71,087 trips a pass |
| 2026-10-29, 1fd2193 (main, merge of 8c5cb30: compact strings) | Claude | dump pass 38.6 s; 3 passes 117.3 s | dump pass 10.8 s; 3 passes 32.5 s (3.61x) | merge gate; dumps identical; 71,087 trips a pass |
| 2026-10-30, aa736e4 (main, merge of a833519: dead code removed) | Claude | dump pass 39.1 s; 3 passes 120.5 s | dump pass 10.9 s; 3 passes 33.1 s (3.65x) | merge gate; dumps identical; 71,087 trips a pass |
| 2026-10-31, 37d344c (wip: SLAM groups compiled; no compiler or runtime change) | Claude (a slower host; compare the ratio only between runs on one host) | 3 passes 190.4 s | 3 passes 49.6 s (3.84x) | dumps identical; 71,087 trips a pass |
| 2026-10-31, 2899c1f (main, merge of 37d344c) | Claude (the slower host) | dump pass 60.4 s; 3 passes 205.5 s | dump pass 16.2 s; 3 passes 51.4 s (4.00x) | merge gate; dumps identical; 71,087 trips a pass; the rise from 3.65x is the host, not the code |

Crossings are calls between compiled code and the interpreter (RX2CPP_BIF_STATS=1 reports them).
