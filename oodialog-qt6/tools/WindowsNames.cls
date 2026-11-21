/* WindowsNames.cls -- Windows file names for ooRexx on Linux, as oodialog-wasm's site/oodfiles.js.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-15, after oodfiles.js 0.1.0 by Claude (Fable 5.2);
 * 2026-11-19, data file names, after oodfiles.js 0.2.0.
 *
 * Windows programs name files in ::requires and CALL with "\" and without regard to case:
 * ::requires "support\View.rex" finds Support/View.rex.  On Linux "support\View.rex" is one file
 * name with a "\" in it.  For every such name written in a program under a directory, the file it
 * means is copied once more under the literal name (since 0.2.0 also for data files a program names in a
 * string, such as "data\Items.txt", or "itemsI.inp" for ItemsI.INP: in the program's directory), in each directory (up to the root given) from
 * which the name resolves the Windows way.  A file found that way finds what it requires by a plain
 * name from its own directory, so those names are followed too.  The programs stay unchanged.
 *
 *   added = .WindowsNames~new(root)~apply      -- the number of names added
 */
::class WindowsNames public
::method init
  expose root kids files add
  use strict arg root
  if root~right(1) == "/" then root = root~left(root~length - 1)
  kids = .directory~new                         -- directory -> StringTable(lower-case name -> real name)
  files = .stringtable~new                      -- absolute path -> 1, every file under root
  add = .stringtable~new                        -- alias -> real path
  call SysFileTree root"/*", "found", "FSO"
  do i = 1 to found.0
    files[found.i] = 1
    self~noteAll(found.i)
  end
  call SysFileTree root"/*", "dirs", "DSO"
  do i = 1 to dirs.0
    self~noteAll(dirs.i)
  end

::method noteAll private                        -- every step of a path below root, as a child of its directory
  expose root kids
  use strict arg path
  rest = path~substr(root~length + 2)
  dir = root
  do while rest \== ""
    parse var rest part "/" rest
    if \kids~hasIndex(dir) then kids[dir] = .stringtable~new
    kids[dir][part~lower] = part
    dir = dir"/"part
  end

::method apply
  expose files add
  do p over files~allIndexes~sort
    do winName over self~names(p)
      if winName~pos("\") == 0 then iterate     -- a plain name: the interpreter finds it by itself
      base = self~up(p)
      do forever                                -- the program's directory, then each one above it, to the root
        real = self~resolve(base, winName)
        alias = base"/"winName
        if real \== .nil then if real \== alias then if \self~has(alias) then do
          add[alias] = real
          self~follow(base, real)
        end
        if \self~isBelowRoot(base) then leave
        base = self~up(base)
      end
    end
  end
  do p over files~allIndexes~sort               -- data files named in strings (oodfiles.js 0.2.0)
    do written over self~dataNames(p)
      real = self~resolve(self~up(p), written~changeStr("/", "\"))
      alias = self~up(p)"/"written
      if real \== .nil then if real \== alias then if \self~has(alias) then add[alias] = real
    end
  end
  do alias over add~allIndexes
    self~copy(add[alias], alias)
  end
  return add~items

/* The strings in a program that look like file names, as oodfiles.js's regular expression finds them:
 * a quote, a run of letters, digits and _ . \ / - space ending in "." and 1 to 5 letters or digits,
 * and the same quote.  After a match the search goes on after the closing quote; otherwise at the
 * next character. */
::method dataNames
  use strict arg path
  out = .array~new
  if \self~isProgram(path) then return out
  text = charin(path, 1, chars(path))
  call stream path, "c", "close"
  alnum = xrange("A", "Z") || xrange("a", "z") || xrange("0", "9")
  set = alnum || "_ .\/-"
  i = 1
  do forever
    i = text~verify("""'", "M", i)               -- the next quote
    if i == 0 then leave
    q = text~substr(i, 1)
    stop = text~verify(set, "N", i + 1)          -- the end of the run of name characters after it
    if stop == 0 then leave
    if text~substr(stop, 1) == q & stop > i + 1 then do
      name = text~substr(i + 1, stop - i - 1)
      dot = name~lastPos(".")
      ext = name~substr(dot + 1)
      if dot > 1 & ext~length >= 1 & ext~length <= 5 & ext~verify(alnum) == 0 then do
        out~append(name)
        i = stop + 1
        iterate
      end
    end
    i = i + 1
  end
  return out

::method isProgram private
  use strict arg path
  ext = path~substr(path~lastPos(".") + 1)~lower
  return "rex cls rxo frm orx"~wordPos(ext) > 0

::method follow private                         -- what a file loaded under an added name requires by plain name
  expose add
  use strict arg base, real
  do name over self~names(real)
    target = self~resolve(self~up(real), name)
    if target == .nil then target = self~resolve(base, name)
    alias = base"/"name
    if target == .nil | target == alias | self~has(alias) then iterate
    add[alias] = target
    self~follow(base, target)
  end

::method has private
  expose files add
  use strict arg path
  return files~hasIndex(path) | add~hasIndex(path)

::method isBelowRoot private
  expose root
  use strict arg dir
  return dir \== root & dir~length > root~length

::method up private
  use strict arg path
  return path~left(path~lastPos("/") - 1)

::method find private
  expose kids
  use strict arg dir, name
  if \kids~hasIndex(dir) then return .nil
  return kids[dir][name~lower]

::method resolve private                        -- the real path of a Windows name from a directory, or .nil
  expose files
  use strict arg base, winName
  parts = winName~makeArray("\")
  dir = base
  do i = 1 to parts~items
    part = parts[i]
    if part == "" | part == "." then iterate
    if part == ".." then do
      dir = self~up(dir)
      iterate
    end
    real = self~find(dir, part)
    if real == .nil & i == parts~items then do
      real = self~find(dir, part".rex")
      if real == .nil then real = self~find(dir, part".cls")
    end
    if real == .nil then return .nil
    dir = dir"/"real
  end
  if files~hasIndex(dir) then return dir
  return .nil

::method names                                  -- the file names a program requires or calls (also used by oodqt_sweep.rex)
  use strict arg path
  out = .array~new
  ext = path~substr(path~lastPos(".") + 1)~lower
  if "rex cls rxo frm orx"~wordPos(ext) == 0 then return out
  text = charin(path, 1, chars(path))
  call stream path, "c", "close"
  upper = text~upper
  do word over .array~of("::REQUIRES", "CALL")
    at = 1
    do forever
      at = upper~pos(word, at)
      if at == 0 then leave
      next = at + word~length
      if word == "CALL" & at > 1 then if upper~substr(at - 1, 1)~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.!?:") == 0 then do
        at = next
        iterate
      end
      after = text~substr(next)
      lead = after~verify(" " || "09"x)        -- whitespace, then a quoted name
      at = next
      if lead <= 1 then iterate
      q = after~substr(lead, 1)
      if q \== '"' & q \== "'" then iterate
      close = after~pos(q, lead + 1)
      if close == 0 then iterate
      name = after~substr(lead + 1, close - lead - 1)
      if name == "" | name~pos("0a"x) > 0 | name~pos("0d"x) > 0 then iterate
      out~append(name)
    end
  end
  return out

::method copy private                           -- the file's bytes once more, under the alias
  use strict arg from, to
  data = charin(from, 1, chars(from))
  call stream from, "c", "close"
  dir = to~left(to~lastPos("/") - 1)                -- a name written with "/" may name a directory spelled otherwise
  if \SysIsFileDirectory(dir) then address system 'mkdir -p "'dir'"'
  call charout to, data, 1
  call stream to, "c", "close"
