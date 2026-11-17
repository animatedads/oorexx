/* oodPrint.cls -- a standby printer for ooDialog programs on ooRexx/WASM.
 * Architecture: Tom Dyer.  Code: Claude (Fable 5.2).
 *
 * A browser page has no printer device and ooDialog has no printing classes.  This file
 * makes a PDF with the estate's ooRexx PDF writer (package oorexx_pdf: PdfCore.cls and the
 * files it requires) and hands it to the user: the page shows it with Print, Open, Save.
 *
 * A program that prints has  ::requires "oodPrint.cls"  and needs PdfCore.cls, PdfDeflate.cls,
 * PdfManagedFonts.cls, FontManager.cls and FontProviders.cls beside it (tools/oodpdfkit.rex
 * collects them).  A program that does not print needs none of this.
 *
 *   .OodPrint~listView(listView, title, fileName)   the columns and rows of a list-view, as a table
 *   .OodPrint~text(text, title, fileName)           paragraphs; an empty line ends a paragraph
 *   .OodPrint~report(aPdfFlowReport, fileName)      a report the program built itself
 *   .OodPrint~file(path, title)                     any file, as it is
 * Each answers the number of bytes handed over.  fileName is optional.
 */
::requires "ooDialog.cls"
::requires "PdfCore.cls"

::class 'OodPrint' public
::method module_version class
  return "0.20.0"

::method file class                -- hand over any file of the program's file system
  use strict arg path, title = ""
  return .oodn~deliver(path, title)

::method report class              -- render a PdfFlowReport (or PdfReport) and hand it over
  use strict arg report, fileName = "report.pdf"
  path = self~pathFor(fileName)
  report~render(path)
  title = report~title
  if title == .nil | title == "" then title = fileName
  return .oodn~deliver(path, title)

::method text class
  use strict arg text, title = "", fileName = "text.pdf"
  report = .PdfFlowReport~new
  if title \== "" then report~title = title
  paragraph = ""
  do line over text~changeStr("0d0a"x, "0a"x)~changeStr("0d"x, "0a"x)~makeArray("0a"x)
    if line~strip == "" then do
      if paragraph \== "" then report~addParagraph(paragraph)
      paragraph = ""
    end
    else if paragraph == "" then paragraph = line
    else paragraph = paragraph || "0a"x || line
  end
  if paragraph \== "" then report~addParagraph(paragraph)
  return self~report(report, fileName)

/* The table has the list-view's columns in their order, with widths in proportion to the
   columns' widths on the screen, and one row for each item.  A column whose every cell is a
   number is set right. */
::method listView class
  use strict arg listView, title = "", fileName = "list.pdf"
  columns = listView~getColumnCount
  if columns < 1 then raise syntax 93.900 array("OodPrint~listView: the list-view has no columns; it must be in report view")
  headers = .array~new
  widths = .array~new
  numeric = .array~new
  do c = 0 to columns - 1
    text = listView~getColumnText(c)
    if text == .nil then text = ""
    headers~append(text)
    width = listView~columnWidthPx(c)
    if \width~datatype("N") then width = 60
    widths~append(max(width, 10))
    numeric~append(.true)
  end
  rows = .array~new
  do i = 0 to listView~items - 1
    row = .array~new
    do c = 0 to columns - 1
      cell = listView~itemText(i, c)
      row~append(cell)
      if cell \== "" then if \cell~datatype("N") then numeric[c + 1] = .false
    end
    rows~append(row)
  end
  table = .PdfTable~new(headers, widths)
  alignments = .array~new
  do c = 1 to columns
    if numeric[c] & rows~items > 0 then alignments~append("right")
    else alignments~append("left")
  end
  table~setAlignments(alignments)
  table~addRows(rows)
  report = .PdfFlowReport~new
  if title \== "" then report~title = title
  if columns > 6 then report~landscape
  report~footer = rows~items "rows"
  report~addTable(table)
  return self~report(report, fileName)

::method pathFor class private     -- where the PDF is written: the temporary directory if there is one
  use strict arg fileName
  if SysIsFileDirectory("/tmp") then return "/tmp/"fileName
  return fileName
