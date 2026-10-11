# rxflow: sandboxed, branch-forced call-flow model (experiment)

`rxflow.sh $REXX rxflow.rex file.rex [maxRuns]` runs a program many times under layers, forcing every
IF/WHEN/WHILE/UNTIL/FOREVER test to a chosen true/false (depth-first over decision vectors), and reports reached
units, caller>callee edges, intercepted effects and the answers each decision site received.

Layers (the OS layer is the guarantee; the Rexx layers intercept and record):
1. read-only, no-network mount namespace (`rxflow.sh`), stdin closed;
2. SecurityManager: COMMAND, CALL (external routines), STREAM blocked and logged;
3. an internal label named like a BIF beats the built-in, so LINEOUT CHAROUT LINEIN CHARIN STREAM LINES CHARS
   DIRECTORY CHDIR are shadowed in every code unit (their arguments are `.context~args`, the whole argument array);
4. package-local classes STREAM FILE RexxQueue Socket shadow the built-ins for the program's code;
5. `::requires` lines are blanked (they would run other programs outside the sandbox) and listed.

Findings: the SecurityManager alone does NOT stop `lineout "f","x"` or `.stream~new(f)~lineout(...)`.
Not modelled: a test's own side effects/calls (the test is replaced, so a function only called inside a test is
reported unreached); line rules for IF/WHILE are single-line.
