/* oodpdfkit.rex -- collect the files a printing ooDialog/WASM program needs from the estate's
 * packages oorexx_pdf and oorexx_font_manager into one directory.
 * Architecture: Tom Dyer.  Code: Claude (Fable 5.2).
 * usage: rexx tools/oodpdfkit.rex ALCHEMY_CLONE OUT_DIR
 * Each step is logged.  Two repairs of PdfCore.cls (oorexx_pdf v0.1-dev6) are applied when
 * they are needed, and reported.  Each is found by the exact faulty text, so when the
 * estate's file is repaired the step reports "not needed" and changes nothing.
 * 1. The line that sets fontResources for the Helvetica path has a string without its
 *    closing quote, so the file does not parse.
 * 2. PdfText~escape writes its strings with C escapes.  Rexx has none: each string holds two
 *    backslashes.  So "(" and ")" print with a backslash before them, and a single
 *    backslash in a text is lost.  The repair writes one backslash. */
parse arg clone out .
if out == "" then do
  say "usage: rexx tools/oodpdfkit.rex ALCHEMY_CLONE OUT_DIR"
  return 2
end
call SysMkDir out
sources = .array~of("packages/oorexx_pdf/src/PdfCore.cls", "packages/oorexx_pdf/src/PdfDeflate.cls", -
                    "packages/oorexx_pdf/src/PdfManagedFonts.cls", "packages/oorexx_font_manager/src/FontManager.cls", -
                    "packages/oorexx_font_manager/src/FontProviders.cls", "packages/oorexx_font_manager/src/FontIntentions.cls")
broken = 'fontResources=" /F1 "||fontRegular||" 0 R /F2 "||fontBold||" 0 R'
do source over sources
  from = .stream~new(clone"/"source)
  if from~query("EXISTS") == "" then do
    say "oodpdfkit: MISSING" clone"/"source
    return 1
  end
  from~open("READ")
  lines = from~arrayIn
  from~close
  name = filespec("NAME", source)
  if name == "PdfCore.cls" then do
    repaired = 0
    do i = 1 to lines~items
      if lines[i]~strip == broken then do
        lines[i] = lines[i]~strip("T")'"'
        repaired = i
      end
    end
    if repaired > 0 then say "oodpdfkit: REPAIRED PdfCore.cls line" repaired": added the closing quote"
    else say "oodpdfkit: repair 1 of PdfCore.cls not needed"
    bs = "5C"x                        -- one backslash
    escapes = 0
    do i = 1 to lines~items              -- the lines of PdfText~escape: each pair of backslashes becomes one
      if lines[i]~strip~abbrev("text = changestr(") & lines[i]~pos(bs || bs) > 0 then do
        lines[i] = lines[i]~changeStr(bs || bs, bs)
        escapes += 1
      end
    end
    if escapes > 0 then say "oodpdfkit: REPAIRED PdfCore.cls, PdfText~escape:" escapes "lines now write one backslash"
    else say "oodpdfkit: repair 2 of PdfCore.cls not needed"
  end
  to = .stream~new(out"/"name)
  to~open("WRITE REPLACE")
  to~arrayOut(lines)
  to~close
  say "oodpdfkit: copied" name "("lines~items "lines)"
end
say "oodpdfkit: done," sources~items "files in" out
return 0
