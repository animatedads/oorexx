# rxtree: source map of a file and its whole ::requires tree (experiment)

`rexx rxtree.rex file.rex` -> TSV rows `kind  package  name  detail  startLine  endLine` for the file and then every
dependency (depth first), plus `edge owner target` and `missing name` rows. Nothing of the program runs.

How the tree is worked:
- the top-level code of each package becomes the body of a synthetic `::method main` (compiled, never run);
- each dependency is copied into a scratch dir with `::options noprolog` placed right before its first directive
  (the option must follow the prologue code) - its prologue never runs - and class-side `::method init class`
  renamed (it runs when the class is installed; the rename is reversed in the output);
- the packages are named inside the scratch dir, because a relative `::requires` is resolved against the requiring
  package's own location - naming them elsewhere silently loads the ORIGINAL files and runs them;
- a `::requires` that cannot be found (also via REXX_PATH / PATH) is blanked and reported as `missing`;
- `::requires x LIBRARY` is left alone; the scratch dir is removed at the end.

Result on the ooRexx 5.3 demo corpus: 38 of 38 files map (5 of them have a missing `rxregexp.cls` / `socket.cls`
somewhere in their tree). Class-side methods are listed (`class-method` rows).
Compared with chatgpt's inspector/ (the model to keep): this adds the requires tree, line ranges and no temp
source rewrite beyond the two rules above; theirs has the lossless hex format, the tests and the collision guards.

## Status
Superseded by `rexx inspector/inspect.rex --tree source scratchdir` (RxRequiresTree on the authoritative inspector): same neutralisation, ::REQUIRES LIBRARY refused. This directory is kept as the experiment record.
