# kernel/gen — class method tables read from the ooRexx source

`setup2methods.rex` reads `interpreter/memory/Setup.cpp` of the ooRexx source tree and writes every primitive-class method
(class, instance/class side, visibility, name, C++ entry, argument count; A_COUNT = open-ended ARGLIST) as TSV.
`methods_5.3.0.tsv` is the output for ooRexx 5.3.0 (658 rows: Object 32+1, String ~100, Array 36, List 27, Directory, ...).
Nothing is copied by hand. The next generator step turns each row into a wrapper that calls the real kernel entry point.

    rexx setup2methods.rex /path/to/oorexx/interpreter/memory/Setup.cpp methods_5.3.0.tsv

Architecture: Tom Dyer. Coding: ChatGPT / Claude. Writer: Sonnet 5.5.
