/* Immutable lexer datum for the restricted ooRexx precompiler. */
::class RxToken public
::attribute kind get
::attribute text get
::attribute line get
::attribute col get
::attribute endLine get
::attribute endCol get
::method init
  expose kind text line col endLine endCol
  use arg kind, text, line, col, endLine = 0, endCol = 0
