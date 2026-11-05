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
| 2026-10-31, 2adce52 (wip: test selection tools; no compiler or runtime change) | Claude (the slower host) | 3 passes 206.7 s | 3 passes 51.6 s (4.00x) | dumps identical; 71,087 trips a pass |
| 2026-10-31, 6c6d420 (main, merge of 2adce52) | Claude (the slower host) | dump pass 62.9 s; 3 passes 220.2 s | dump pass 17.6 s; 3 passes 54.9 s (4.01x) | merge gate; dumps identical; 71,087 trips a pass |
| 2026-11-02, e39d0a2 (wip: selection by function; no compiler or runtime change) | Claude (a faster host again) | 3 passes 135.2 s | 3 passes 39.2 s (3.45x) | dumps identical; 71,087 trips a pass |
| 2026-11-02, 3c21ded (main, merge of e39d0a2) | Claude | dump pass 49.4 s; 3 passes 153.1 s | dump pass 12.8 s; 3 passes 43.2 s (3.54x) | merge gate; dumps identical; 71,087 trips a pass |
| 2026-11-04, 45f122a (wip: BIF dispatch without strlen chains) | Claude | dump pass 47.8 s; 3 passes 145.9 s | dump pass 11.3 s; 3 passes 31.9 s (4.57x) | dumps identical; 71,087 trips a pass |
| 2026-11-04, a388f54 (main, merge of 45f122a) | Claude | dump pass 48.3 s; 3 passes 143.7 s | dump pass 10.9 s; 3 passes 32.8 s (4.38x) | merge gate; dumps identical; 71,087 trips a pass |
| 2026-11-04, 56dea1a (wip: ~SUBSTR fast path reachable; slot vectors reserved) | Claude | dump pass 49.8 s; 3 passes 146.6 s | dump pass 10.1 s; 3 passes 32.8 s (4.48x) | dumps identical; 71,087 trips a pass |
| 2026-11-04, 8f5133a (main, merge of 56dea1a) | Claude | dump pass 49.8 s; 3 passes 152.6 s | dump pass 11.2 s; 3 passes 32.9 s (4.64x) | merge gate; dumps identical; 71,087 trips a pass |
| 2026-11-05, 5ac7c97 (wip: Frame exposed bits; string methods skip the number parse) | Claude | dump pass 35.4 s; 3 passes 96.2 s | dump pass 7.1 s; 3 passes 21.6 s (4.46x) | faster host after a container restart: compare by ratio; dumps identical; 71,087 trips a pass |
| 2026-11-05, 3d57776 (main, merge of 5ac7c97) | Claude | dump pass 30.2 s; 3 passes 96.4 s | dump pass 6.9 s; 3 passes 22.3 s (4.32x) | merge gate; faster host; dumps identical; 71,087 trips a pass |
| 2026-11-05, 31ae690 (wip: USE ARG into the frame slot; omitted EXPOSEd argument dropped) | Claude | dump pass 31.8 s; 3 passes 96.4 s | dump pass 7.6 s; 3 passes 23.1 s (4.17x) | dumps identical; 71,087 trips a pass; A/B against 5ac7c97 on this host: 22.79 s against 23.16 s |
| 2026-11-05, bd70b08 (main, merge of 31ae690) | Claude | dump pass 34.5 s; 3 passes 99.4 s | dump pass 7.2 s; 3 passes 23.8 s (4.18x) | merge gate; dumps identical; 71,087 trips a pass |
| 2026-11-05, 2fdc0af (wip: message sends without throwaway strings; ARG(n, 'E'/'O') in place) | Claude | dump pass 32.9 s; 3 passes 96.6 s | dump pass 7.3 s; 3 passes 22.7 s (4.25x) | dumps identical; 71,087 trips a pass; rexxcps compile 3,418 M instructions (-14.4% from 31ae690) |
| 2026-11-05, 2ae1c73 (main, merge of 2fdc0af) | Claude | dump pass 31.5 s; 3 passes 99.6 s | dump pass 7.4 s; 3 passes 22.8 s (4.37x) | merge gate; dumps identical; 71,087 trips a pass |
| 2026-11-05, f3f1934 (wip: Frame owner slot cache; rx::sendSubstr / sendLength) | Claude | dump pass 33.1 s; 3 passes 100.9 s | dump pass 7.1 s; 3 passes 22.8 s (4.43x) | dumps identical; 71,087 trips a pass; rexxcps compile 2,968 M instructions (-13.2% from 2fdc0af) |
| 2026-11-05, 0caa741 (main, merge of f3f1934) | Claude | dump pass 33.1 s; 3 passes 98.5 s | dump pass 7.6 s; 3 passes 22.0 s (4.47x) | merge gate; dumps identical; 71,087 trips a pass |
| 2026-11-05, 0caa741, **Release interpreter** de1db87 | Claude | dump pass 17.6 s; 3 passes 59.5 s | dump pass 7.2 s; 3 passes 21.8 s (2.73x) | Release interpreter for both columns; dumps identical (and identical to the oracle's). The rows above use the unoptimized oracle (r13196, -g, no -O) |
| 2026-11-05, 288be4b (wip: class scope without the lock; rx::sendContains / sendIsA / string[i]) | Claude | dump pass 32.9 s; 3 passes 96.7 s | dump pass 6.9 s; 3 passes 20.0 s (4.83x) | dumps identical; 71,087 trips a pass; one pass under callgrind 44.35 G instructions (-12.9% from 0caa741's 50.94 G) |
| 2026-11-05, 288be4b, **Release interpreter** de1db87 | Claude | dump pass 17.9 s; 3 passes 48.7 s | dump pass 6.4 s; 3 passes 17.7 s (2.76x) | Release interpreter for both columns; dumps identical |
| 2026-11-05, 204b570 (main, merge of 288be4b) | Claude | dump pass 34.1 s; 3 passes 98.2 s | dump pass 6.6 s; 3 passes 20.7 s (4.73x) | merge gate; dumps identical; 71,087 trips a pass |
| 2026-11-05, 204b570, **Release interpreter** de1db87 | Claude | dump pass 17.9 s; 3 passes 49.6 s | dump pass 6.1 s; 3 passes 19.5 s (2.55x) | merge gate; Release interpreter for both columns; dumps identical |

Crossings are calls between compiled code and the interpreter (RX2CPP_BIF_STATS=1 reports them).
