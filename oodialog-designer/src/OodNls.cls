/* OodNls.cls -- language support from ::RESOURCE string tables: one piece of
   code for the ooDialog Designer's own interface and for the programs it
   writes.  Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   A string table is a ::RESOURCE strings.<language> of key = text lines
   (-- starts a comment line).  nlsUse picks the language and loads its table
   over the base language's; nls(key, a1, a2, ...) gives a key's text with
   %1, %2, ... replaced by a1, a2, ... in one pass.

   The designer inherits OodNls and passes the package its tables are in.  A
   program the designer writes gets these same methods, copied by
   OodNls~programLines from their source, into its dialog class; there the
   tables default to .resources, the program's own. */

::class OodNls public mixinclass Object

::method module_version class
  return "0.9.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.9.0"
::method module_lastChanged
  return "2026-11-15"

-- The lines a program gets: the methods' and the routine's own source.
::method programLines class
  use strict arg base
  out = .array~new
  out~append("-- Language support (OodNls.cls of the ooDialog Designer): texts are in")
  out~append("-- ::RESOURCE strings.<language> at the end (key = text).  self~nls(key, a1, a2, ...)")
  out~append("-- gives a key's text with %1, %2, ... replaced by a1, a2, ...; a key a language")
  out~append("-- lacks takes" '"'base'"'"'s.")
  out~append("::attribute nlsLanguage get")
  out~append("")
  do name over .array~of("nlsUse", "nls")
    out~append("::method" name "unguarded")
    do l over self~method(name~upper)~source
      out~append(l)
    end
    out~append("")
  end
  return out

::method routineLines class
  out = .array~of("::routine nlsAnsi")
  do l over .context~package~findRoutine("NLSANSI")~source
    out~append(l)
  end
  out~append("")
  return out

::attribute nlsLanguage get

-- Pick the language and load its table over the base's.  lang: the one asked
-- for (de, de_AT, de-AT); "" takes LC_ALL, LC_MESSAGES, then LANG (C and POSIX
-- name none).  de_AT without a table of its own is de; no table is base.
-- tables: the ::RESOURCE string tables (.resources: this package's).
-- Answers the language used.
::method nlsUse unguarded
  expose nlsTable nlsLanguage
  use strict arg lang = "", base = "en", tables = (.resources)
  if lang == .nil then lang = ""
  if lang == "" then do var over .array~of("LC_ALL", "LC_MESSAGES", "LANG")
    lang = value(var, , "ENVIRONMENT")
    if lang \== "", lang~upper \== "C", lang~upper \== "POSIX" then leave
    lang = ""
  end
  parse var lang lang "." .                    -- de_DE.UTF-8: de_DE
  lang = lang~changeStr("-", "_")               -- de-AT: de_AT
  if tables["STRINGS."lang~upper] == .nil then lang = lang~left(2)
  if tables["STRINGS."lang~upper] == .nil then lang = base
  nlsLanguage = lang
  nlsTable = .directory~new
  parse source os .
  order = .array~of(base)
  if lang \== base then order~append(lang)
  do table over order
    lines = tables["STRINGS."table~upper]
    if lines == .nil then iterate
    do line over lines
      parse var line key "=" text
      key = key~strip
      if key == "" | key~left(2) == "--" then iterate
      text = text~strip("L")
      if text == "", table \== base then iterate   -- untranslated: the base's
      -- ooDialog on Windows takes ANSI text: the file is UTF-8
      if os~caselessPos("Windows") = 1 then text = nlsAnsi(text)
      nlsTable[key~upper] = text
    end
  end
  return lang

-- A key's text; %1, %2, ... take the arguments after the key.
::method nls unguarded
  expose nlsTable
  use strict arg key, ...
  text = nlsTable[key~upper]
  if text == .nil then return "<"key">"     -- a missing key shows itself
  if arg() = 1 then return text
  -- one pass: %n becomes argument n+1; what goes in is not looked at again
  out = ""
  i = 1
  do forever
    p = text~pos("%", i)
    if p = 0 then leave
    n = text~substr(p + 1)~verify("0123456789") - 1
    if n < 0 then n = text~length - p
    k = text~substr(p + 1, n)
    if n > 0, k > 0, k < arg() then do
      out = out || text~substr(i, p - i) || arg(k + 1)
      i = p + 1 + n
    end
    else do
      out = out || text~substr(i, p - i + 1)
      i = p + 1
    end
  end
  return out || text~substr(i)

-- Every key's text, key TAB text, keys as the table has them (upper case):
-- for a page that shows the texts.  (Not copied into programs.)  It is here
-- because only OodNls's own methods see its object variables.
::method nlsTableLines
  expose nlsTable
  out = .array~new
  do key over nlsTable~allIndexes~sort
    out~append(key || "09"x || nlsTable[key])
  end
  return out~makeString("L", "0a"x)

-- UTF-8 to Windows-1252 (Western European), for ooDialog on Windows; a
-- character Windows-1252 has not becomes ?
::routine nlsAnsi
  use strict arg s
  if s~verify(xrange("00"x, "7F"x)) = 0 then return s
  special = "E282AC 80 E2809A 82 C692 83 E2809E 84 E280A6 85 E280A0 86 E280A1 87"
  special = special "CB86 88 E280B0 89 C5A0 8A E280B9 8B C592 8C C5BD 8E E28098 91 E28099 92"
  special = special "E2809C 93 E2809D 94 E280A2 95 E28093 96 E28094 97 CB9C 98 E284A2 99"
  special = special "C5A1 9A E280BA 9B C593 9C C5BE 9E C5B8 9F"
  out = ""
  i = 1
  do while i <= s~length
    c = s~subchar(i)
    b = c~c2d
    select
      when b < 128 then do
        out = out || c
        i = i + 1
      end
      when b = 194 | b = 195 then do   -- C2 xx, C3 xx: U+0080 to U+00FF
        out = out || d2c(s~subchar(i + 1)~c2d + 64 * (b - 194))
        i = i + 2
      end
      otherwise do
        n = 2
        if b >= 224 then n = 3
        if b >= 240 then n = 4
        k = wordpos(s~substr(i, n)~c2x, special)
        if k > 0 then out = out || special~word(k + 1)~x2c
        else out = out || "?"
        i = i + n
      end
    end
  end
  return out
