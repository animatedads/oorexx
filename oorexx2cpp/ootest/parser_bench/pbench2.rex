/* pbench2.rex -- parse the Parser's own sources: count elements and time
   PASSES passes; with a file name, also dump one line per element there
   (to compare a compiled run with an interpreted one). */
  Parse Arg passes out .
  If passes == "" Then passes = 1
  files = .Array~of("Rexx.Parser.cls")
  Call SysFileTree "parser/*.cls", "f.", "FO"
  Do i = 1 To f.0; files~append(f.i); End
  If out \== "" Then Do
    Call SysFileDelete out
    Do file Over files
      source = CharIn(file, 1, Chars(file))~makeArray
      Call Stream file, "C", "Close"
      parser = .Rexx.Parser~new(file, source)
      Call LineOut out, "FILE" FileSpec("Name", file)
      element = parser~firstElement
      Do Until element == .Nil
        Call LineOut out, element~class~id element~category element~from element~to c2x(element~value)
        element = element~next
      End
    End
    Call LineOut out
    Say "dump written to" out
  End
  t0 = .DateTime~new
  Do pass = 1 To passes
    total = 0
    Do file Over files
      source = CharIn(file, 1, Chars(file))~makeArray
      Call Stream file, "C", "Close"
      parser = .Rexx.Parser~new(file, source)
      element = parser~firstElement
      Do Until element == .Nil
        total += 1
        element = element~next
      End
    End
    Say "pass" pass":" files~items "files," total "elements"
  End
  Say "elapsed:" (.DateTime~new - t0)~totalSeconds~format(,2) "s"
  Exit 0
::Requires "Rexx.Parser.cls"
