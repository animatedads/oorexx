/* t17: .application~srcDir is the directory of the program that was started,
   also when it is asked from a file in another directory and from another thread. */
say "log: main" .application~srcDir
say "log: lib" .Asker~new~ask
say "log: thread" .Asker~new~start("ask")~result
return 0
::requires "ooDialog.cls"
::requires "lib/Asker.cls"
