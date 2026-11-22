/* t01_object.rex -- the Object Editor's model without a browser.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
   usage: rexx t01_object.rex PATH/Person.cls      (ObjectEditor.cls on REXX_PATH) */
parse arg file
file = file~strip
if file == "" then file = "Person.cls"
fails = 0
checks = 0
text = .stream~new(file)~charIn(1, .stream~new(file)~chars)
call check "the text survives being split into directives", .OxSource~new(text)~text == text

w = .OxWorkspace~new(file, text)

-- 1. what reflection finds
call check "classes in file order", w~classNames == "Printable Person Employee"
parse value w~classInfo("Employee") with nm "09"x sup "09"x mix "09"x isMix "09"x pub "09"x abs "09"x .
call check "Employee's superclass, mixin and public", (sup mix pub isMix) == "Person Printable 1 0"
call check "Printable is a mixin", w~classInfo("Printable")~pos("09"x || "1" || "09"x || "1" || "09"x || "0" || "09"x) > 0
h = w~hierarchy("Employee")~makeArray("0a"x)
call check "hierarchy from Object down", h~items = 3 & h[1]~left(9) == "0" || "09"x || "Object" || "09"x & h[3]~left(22) == "2" || "09"x || "Employee" || "09"x || "Printable" || "09"x || "P"
call check "subclasses of Person", w~subclassNames("Person") == "Employee"
own = ownMembers(w~members("Person"))
call check "Person's own members in file order", own == "name born notes KIND init age addNote"
m = memberLine(w~members("Person"), "notes")
call check "notes is a private attribute", m~word(2) m~word(3) == "ATTRIBUTE private"
call check "addNote is unguarded", memberLine(w~members("Person"), "addNote")~word(4) == "unguarded"
call check "KIND is a constant", memberLine(w~members("Person"), "KIND")~word(2) == "CONSTANT"
call check "Object's methods inherited", memberLine(w~members("Person"), "objectname")~word(6) == "Object"
call check "lookup order: own, mixin, superclass, Object", lookupOrder(w~members("Employee")) == "Employee Printable Person Object"
emp = w~members("Employee")
call check "Employee inherits print from its mixin", memberLine(emp, "print")~word(6) == "Printable"
call check "Employee inherits name from Person", memberLine(emp, "name")~word(6) == "Person"
cls = w~members("Person", "CLASS")
call check "class side: fromJson own", memberLine(cls, "fromJson")~word(7) == "1"
call check "class side: new is Object's class method", memberLine(cls, "new")~word(6) == "Object"
call check "class side: subclass from Class", memberLine(cls, "subclass")~word(6) == "Class"
call check "::requires json.cls brings its classes", w~requiresInfo~caselessPos("json.cls" || "09"x) = 1 & w~requiresInfo~pos("JSON") > 0

-- 2. edits, each reloaded and seen by reflection
w~addAttribute("Person", "email")
call check "attribute added", memberLine(w~members("Person"), "email")~word(2) == "ATTRIBUTE"
call check "  after the class's last member", w~text~pos("  notes~append(text)" || "0a"x || "0a"x || "::method fromJson class" || "0a"x) > 0 | w~text~pos("::attribute email") > w~text~pos("::method fromJson")
w~setMemberFlags("Person", "age", "INSTANCE", "INSTANCE", "private", "unguarded")
call check "age made private and unguarded", memberLine(w~members("Person"), "age")~word(3) memberLine(w~members("Person"), "age")~word(4) == "private unguarded"
call check "  the directive rewritten", w~text~pos("::method age private unguarded") > 0
w~setMemberFlags("Person", "age", "INSTANCE", "INSTANCE", "public", "guarded")
call check "  and back", w~text~pos("::method age" || "0a"x) > 0
w~addMethod("Person", "display", "INSTANCE", "package")
call check "method added with package scope", memberLine(w~members("Person"), "display")~word(3) == "package"
w~addMethod("Person", "named", "CLASS")
call check "class method added", memberLine(w~members("Person", "CLASS"), "named")~word(7) == "1"
call check "setBody that compiles", w~setBody("Person", "display", "INSTANCE", 'say self~name') == ""
call check "  body read back", w~getBody("Person", "display", "INSTANCE") == "say self~name"
err = w~setBody("Person", "display", "INSTANCE", 'if then')
call check "setBody that does not compile is kept, with the message", err~pos("Error") = 1 & w~getBody("Person", "display", "INSTANCE") == "if then"
call check "  reflection keeps the last good load", memberLine(w~members("Person"), "display") \== ""
call check "  fixed again", w~setBody("Person", "display", "INSTANCE", 'say self~name') == ""
w~removeMember("Person", "display", "INSTANCE")
w~removeMember("Person", "named", "CLASS")
w~removeMember("Person", "email", "INSTANCE")
call check "removing them gives the file back", w~text == text
w~addClass("Manager", "Employee")
call check "class added under Employee", w~subclassNames("Employee") == "Manager"
w~setClass("Manager", "Person", "Printable", 1, 0)
call check "class moved under Person with the mixin", w~classInfo("Manager")~left(26) == "Manager" || "09"x || "Person" || "09"x || "Printable" || "09"x || "0"
w~removeClass("Manager")
call check "class removed", w~text == text
call refuses "a superclass that does not exist", "w~addClass('Bad', 'NoSuchClass')"
call check "  text unchanged after the refusal", w~text == text
call refuses "a ::requires that does not load", "w~addRequires('nosuch.cls')"
call refuses "a member name already taken", "w~addAttribute('Person', 'name')"
call refuses "flags on a constant", "w~setMemberFlags('Person', 'KIND', 'INSTANCE', 'INSTANCE', 'private', 'guarded')"
w~addRequires("csvStream.cls")
call check "::requires csvStream.cls loads its classes", w~requiresInfo~caselessPos("csvStream.cls" || "09"x) > 0 & w~knownClasses~hasIndex("CSVSTREAM")

-- 3. completion, asked of the objects
call check "self~na in Employee", labels(w~complete("Employee", "INSTANCE", "  return self~na")) == "name"
c = labels(w~complete("Employee", "INSTANCE", "  self~"))
call check "self~ has own, inherited, mixin and private", wordpos("salary", c) > 0 & wordpos("print", c) > 0 & wordpos("notes", c) > 0 & wordpos("objectname", c) > 0
call check "operators are not offered after ~", wordpos("||", c) = 0 & wordpos("==", c) = 0
call check ".Pe gives Person", labels(w~complete("Person", "INSTANCE", "  x = .Pe")) == "Person"
call check ".Js gives JSON from ::requires", wordpos("JSON", labels(w~complete("Person", "INSTANCE", "  x = .Js"))) > 0
c = labels(w~complete("Person", "INSTANCE", "  x = .Person~"))
call check ".Person~ gives its class side", wordpos("fromJson", c) > 0 & wordpos("new", c) > 0
c = labels(w~complete("Person", "INSTANCE", "  p = .Employee~new('Ann')" || "0a"x || "  say p~"))
call check "p~ after p = .Employee~new(...) gives Employee's public members", wordpos("salary", c) > 0 & wordpos("age", c) > 0 & wordpos("notes", c) = 0
call check "expose gives the attributes", labels(w~complete("Person", "INSTANCE", "  expose n")) == "name notes"
call check "'text'~le gives String's", wordpos("left", labels(w~complete("Person", "INSTANCE", "  say 'abc'~le"))) > 0
call check "a variable of unknown class gives nothing", labels(w~complete("Person", "INSTANCE", "  say q~")) == ""
call check "plain words: variables and keywords", wordpos("text", labels(w~complete("Person", "INSTANCE", "  use strict arg text" || "0a"x || "  t"))) > 0

-- 4. examining does not run the file's main code
pw = .OxWorkspace~new("Prog.rex", 'say "MAIN CODE RAN"; .local~oxRan = 1' || "0a"x || "::class Thing public" || "0a"x)
call check "the prolog is not run when examining", .local~hasIndex("OXRAN") == .false & pw~classNames == "Thing"

d = w~docsOf("Person")
call check "ooRexxDoc read by the Rexx Parser: the class's, from the prolog", d~pos("CLASS" || "09"x || "person" || "09"x || "A person, with a name and the year they were born.") > 0
call check "  a member's summary and its tags", d~pos("METHOD" || "09"x || "age" || "09"x || "Age in whole years.") > 0 & d~pos("@return the age") > 0
call check "  a --- doc-comment", d~pos("ATTRIBUTE" || "09"x || "name" || "09"x || "The person's name, as written.") > 0
call check "  none for a class with no source", w~docsOf("Object") == ""
-- 9. writing ooRexxDoc (the code assistance "Document" task applies its answer so)
call check "getDoc: a member's /** */", w~getDoc("Person", "age", "INSTANCE")~left(3) == "/**" & w~getDoc("Person", "age", "INSTANCE")~pos("@return the age") > 0
call check "getDoc: a --- doc-comment", w~getDoc("Person", "name", "INSTANCE") == "--- The person's name, as written."
call check "getDoc: the class's", w~getDoc("Person")~pos("A person, with a name") > 0
call check "getDoc: none", w~getDoc("Person", "addNote", "INSTANCE") == "" & w~getDoc("Printable") == ""
call check "memberText: the directive and body", w~memberText("Person", "addNote", "INSTANCE") == "::method addNote unguarded" || "0a"x || "  expose notes" || "0a"x || "  use strict arg text" || "0a"x || "  notes~append(text)"
call check "memberText: the class's directive", w~memberText("Employee") == "::class Employee public subclass Person inherit Printable"
dw = .OxWorkspace~new(file, text)
call check "setDoc: a new doc, before the member", dw~setDoc("Person", "addNote", "INSTANCE", "/** Adds a note." || "0a"x || " * @param text  the note" || "0a"x || " */") == ""
call check "  read back, and seen by the Rexx Parser", dw~getDoc("Person", "addNote", "INSTANCE")~pos("@param text") > 0 & dw~docsOf("Person")~pos("METHOD" || "09"x || "addnote" || "09"x || "Adds a note.") > 0
call check "  a blank line above it, the member's code kept", dw~text~pos("  return date(""S"")~left(4) - born~left(4)" || "0a"x || "0a"x || "/** Adds a note.") > 0 & dw~getBody("Person", "addNote", "INSTANCE")~pos("notes~append(text)") > 0
call check "setDoc: a --- doc replaced by a /** */", dw~setDoc("Person", "name", "INSTANCE", "/** The name. */") == "" & dw~getDoc("Person", "name", "INSTANCE") == "/** The name. */" & dw~text~pos("--- The person's") = 0
call check "setDoc: the class's, after the ordinary comment", dw~setDoc("Employee", "", "INSTANCE", "--- Someone paid.") == "" & dw~getDoc("Employee") == "--- Someone paid." & dw~text~pos("--- Someone paid." || "0a"x || "::class Employee") > 0
call check "setDoc: an empty text removes it", dw~setDoc("Person", "age", "INSTANCE", "") == "" & dw~getDoc("Person", "age", "INSTANCE") == "" & dw~text~pos("Age in whole years") = 0
call check "setDoc: an ordinary /* */ before a member is not taken for a doc", dw~getDoc("Printable") == "" & dw~text~left(17) == "/* Person.cls -- "

call refuses "setDoc: a /* */ comment is not ooRexxDoc", "w~setDoc('Person', 'init', 'INSTANCE', '/* not a doc */')"
call refuses "setDoc: two comments in one", "w~setDoc('Person', 'init', 'INSTANCE', '/** one */' || '0a'x || '/** two */')"
call refuses "setDoc: a member that is not there", "w~setDoc('Person', 'nosuch', 'INSTANCE', '/** x */')"
call check "module_version", .OxWorkspace~module_version == "0.5.0" & w~module_version == "0.5.0"
say "t01_object:" checks - fails "of" checks "checks passed"
if fails > 0 then return 1
return 0

-- the names of the own members, in order
ownMembers: procedure
  use arg omText
  omOut = ""
  do omLine over omText~makeArray("0a"x)
    parse var omLine omName "09"x . "09"x . "09"x . "09"x . "09"x . "09"x omOwn
    if omOwn == "1" then omOut = omOut omName
  end
  return omOut~strip

-- one member's fields, blank separated: name kind visibility guard abstract definedIn own
memberLine: procedure
  use arg mlText, mlName
  do mlLine over mlText~makeArray("0a"x)
    parse var mlLine mlN "09"x .
    if mlN~caselessEquals(mlName) then return mlLine~changeStr("09"x, " ")
  end
  return ""

-- the classes members come from, in order
lookupOrder: procedure
  use arg loText
  loOut = ""
  do loLine over loText~makeArray("0a"x)
    parse var loLine . "09"x . "09"x . "09"x . "09"x . "09"x loFrom "09"x .
    if wordpos(loFrom, loOut) = 0 then loOut = loOut loFrom
  end
  return loOut~strip

labels: procedure
  use arg lbText
  lbOut = ""
  do lbLine over lbText~makeArray("0a"x)
    parse var lbLine lbL "09"x .
    lbOut = lbOut lbL
  end
  return lbOut~strip

check: procedure expose fails checks
  use arg ckLabel, ckOk
  checks = checks + 1
  if ckOk then say "  ok  " ckLabel
  else do
    say "  FAIL" ckLabel
    fails = fails + 1
  end
  return

refuses: procedure expose fails checks w
  use arg rfLabel, rfCode
  checks = checks + 1
  signal on syntax name rfRefused
  interpret rfCode
  say "  FAIL not refused:" rfLabel
  fails = fails + 1
  return
rfRefused:
  -- the editor's own refusal: Error 93.900 with its message, not any error
  if condition("O")~at("CODE") \== "93.900" | condition("O")~at("ADDITIONAL")~isA(.Array) = .false then do
    say "  FAIL refused, but not by the editor:" rfLabel "--" condition("O")~at("MESSAGE")
    fails = fails + 1
    return
  end
  say "  ok   refuses" rfLabel "--" condition("O")~at("ADDITIONAL")[1]~left(110)
  return

::requires "ObjectEditor.cls"
