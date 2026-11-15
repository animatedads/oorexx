/* t16: Windows file names. ::requires and CALL written with "\" and in another
   case find their files (site/oodfiles.js adds the names when the files are
   loaded); a file found that way finds what it requires from its own directory. */
call "parts\Report.rex" "called"
say "log:" .Helper~new~answer
return 0
::requires "parts\helper.cls"
