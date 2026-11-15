/* OxUi.cls -- the ooRexx Object Editor's own texts, and the Libraries
   panel's (shared with the ooDialog Designer), in every language they have:
   ::RESOURCE strings.<language>, key = text, read by OodNls (OodNls.cls of
   the ooDialog Designer), the same language support the designer uses.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).  German: Claude (Opus 5.5),
   to be checked by a German speaker.

   .OxUi~use(lang), .OxUi~text(key, ...), oxT(key, ...), .OxUi~tableLines,
   .OxUi~languages: as OodUi (OodUi.cls). */

::requires "OodNls.cls"

::class OxUi public inherit OodNls

::attribute current class

::method use class
  use strict arg lang = ""
  ui = self~new
  used = ui~nlsUse(lang, "en", .resources)   -- this package's tables
  self~current = ui
  return used

::method text class
  use strict arg key, ...
  if \self~current~isA(.OxUi) then self~use   -- (an attribute never set is its own name)
  forward to (self~current) message "NLS"

::method tableLines class
  if \self~current~isA(.OxUi) then self~use
  return self~current~nlsTableLines

::method languages class
  out = "en"
  do name over .resources~allIndexes~sort
    if name~left(8) == "STRINGS.", name \== "STRINGS.EN" then out = out name~substr(9)~lower
  end
  return out

::routine oxT public
  use strict arg key, ...
  return .OxUi~sendWith("TEXT", arg(1, "A"))

::resource strings.en
-- the Object Editor
ox.name = ooRexx Object Editor
ox.footer = Architecture: Tom Dyer.  Code: Claude (Opus 5.5).  ooRexx/WASM runtime: Josep Maria Blasco.  Everything shown is found by examining the loaded classes (ooRexx reflection), not by reading the text.
ox.noStart = Could not start:
ox.lang.tip = The editor's own language
ox.lang.now = The editor speaks %1 now.
ox.ex.tip = Open an example
ox.ex.new = New data object
ox.ex.person = Person.cls (data objects)
ox.ex.calculator = Calculator.rex (an ooDialog program)
ox.open = Open…
ox.open.tip = Open a .cls or .rex
ox.save = Save
ox.save.tip = Download the file
ox.source = Source
ox.source.tip = Show the whole file
ox.libraries = Libraries…
ox.libraries.tip = Connect to a source of ooRexx libraries and use one
ox.classes = Classes
ox.newClass = new class
ox.subclassOf = subclass of
ox.subclassOfX = subclass of %1
ox.hierarchy = Hierarchy
ox.subclasses = subclasses: %1
ox.requires.hint = (their public classes complete too)
ox.requires.remove.tip = Remove this ::requires
ox.requires.removed = Removed ::requires %1
ox.requires.noClasses = (no public classes)
ox.requires.added = ::requires "%1" added; its classes now complete.
ox.side.instance = Instance side
ox.side.class = Class side
ox.showInherited = show inherited
ox.inheritedFrom = inherited from %1 (%2)
ox.group.open.tip = Show these members
ox.group.close.tip = Hide these members
ox.op.abuttal = (abuttal)
ox.op.blank = (blank concatenation)
ox.doc.noSummary = (documented; click for the text)
ox.doc.none = No ooRexxDoc for this one.
ox.col.name = name
ox.col.kind = kind
ox.col.visibility = visibility
ox.col.guard = guard
ox.col.abstract = abstract
ox.col.definedIn = defined in
ox.newMember = new member name
ox.value = value
ox.add = Add
ox.apply = Apply
ox.removeClass = Remove class
ox.none = none
ox.remove.tip = Remove %1
ox.classAdded = Added class %1.
ox.classChanged = Class %1 changed.
ox.classRemoved = Removed class %1.
ox.memberAdded = Added %1 %2.
ox.memberRemoved = Removed %1.
ox.flags = %1: %2
ox.reloaded = (reloaded)
ox.opened = Opened %1: %2 classes, found by reflection.
ox.pickMethod = Pick a method
ox.code.placeholder = The method's body.  ~ after self, .Name, a variable or a string lists what it answers; . lists the classes; Ctrl+Space anywhere.
ox.compiles = compiles
ox.saved = Saved %1.
ox.copied = Copied.
ox.copy = Copy
ox.close = Close
-- the Libraries panel (shared by the Object Editor and the ooDialog Designer)
libs.title = Libraries
libs.refresh = Refresh from GitHub
libs.refresh.tip = Read the repository's tree from GitHub
libs.owner = owner
libs.repo = repo
libs.connect = Connect GitHub repo
libs.upload = Upload files…
libs.close = Close
libs.filter = filter: logging, maths, …
libs.pick = Pick a library.
libs.reading = Reading %1 from GitHub…
libs.fromGitHub = %1 libraries, from GitHub.
libs.connected = Connected %1.
libs.uploaded = %1 file(s) added to the local provider.
libs.readingCatalogue = Reading the catalogue…
libs.file = %1 file
libs.files = %1 files
libs.none = Nothing matches.
libs.readingOne = Reading…
libs.install = Install and show what it offers
libs.use = Use it here
libs.installing = Installing %1 and what it requires…
libs.installed = Installed %1.  Loading it to see what it offers…
libs.subclassOf = (subclass of %1)
libs.ready = Ready: %1 public classes.  "Use it here" adds the ::requires.
libs.provider.local = Files from this computer
-- the editor and the library providers refuse
ox.err.noClassHere = No class %1 in this file
ox.err.compile = The file does not compile: %1
ox.err.notDone = Not done, it does not compile: %1
ox.err.unknownClass = No class %1 is known here
ox.err.notClass = %1 is not a class
ox.err.name.needed = A %1 name is needed
ox.err.name.start = A %1 name starts with a letter: %2
ox.err.name.chars = Not a %1 name: %2
ox.err.visibility = visibility is public, private or package
ox.err.guard = guard is guarded or unguarded
ox.err.classExists = There is already a class %1
ox.err.noClassHere2 = No class %1 in this file
ox.err.memberExists = %1 already has %2
ox.err.noOwnSide = %1 has no own %2 on the %3 side
ox.err.constant = A constant has no options to change
ox.err.noOwn = %1 has no own %2
ox.err.notMethod = %1 is not a method
ox.err.directive = A line of a method cannot start with ::
ox.err.whichFile = Which file?
ox.err.requiresAlready = It already requires %1
ox.err.requiresNot = It does not require %1
ox.err.http = HTTP %1 for %2
ox.err.noFile = No file %1
ox.err.github = GitHub API answered %1 for %2
ox.err.path = Not a path inside the folder: %1
ox.err.providerExists = A provider %1 is already registered
ox.err.noProvider = No provider %1
ox.err.noLibrary = No library %1
ox.err.notLibFile = %1 is not a file of %2
ox.err.notInstalled = Not installed: %1
::END

::resource strings.de
-- Deutsch: übersetzt von Claude (Opus 5.5); bitte von einem Muttersprachler prüfen
-- der Objekteditor
ox.name = ooRexx-Objekteditor
ox.footer = Architektur: Tom Dyer.  Code: Claude (Opus 5.5).  ooRexx/WASM-Laufzeit: Josep Maria Blasco.  Alles Gezeigte wird durch Untersuchen der geladenen Klassen gefunden (ooRexx-Reflexion), nicht durch Lesen des Texts.
ox.noStart = Start nicht möglich:
ox.lang.tip = Die Sprache des Editors
ox.lang.now = Der Editor spricht jetzt %1.
ox.ex.tip = Ein Beispiel öffnen
ox.ex.new = Neues Datenobjekt
ox.ex.person = Person.cls (Datenobjekte)
ox.ex.calculator = Calculator.rex (ein ooDialog-Programm)
ox.open = Öffnen…
ox.open.tip = Eine .cls oder .rex öffnen
ox.save = Speichern
ox.save.tip = Die Datei herunterladen
ox.source = Quelltext
ox.source.tip = Die ganze Datei zeigen
ox.libraries = Bibliotheken…
ox.libraries.tip = Mit einer Quelle von ooRexx-Bibliotheken verbinden und eine verwenden
ox.classes = Klassen
ox.newClass = neue Klasse
ox.subclassOf = Unterklasse von
ox.subclassOfX = Unterklasse von %1
ox.hierarchy = Hierarchie
ox.subclasses = Unterklassen: %1
ox.requires.hint = (ihre öffentlichen Klassen werden auch ergänzt)
ox.requires.remove.tip = Dieses ::requires entfernen
ox.requires.removed = ::requires %1 entfernt
ox.requires.noClasses = (keine öffentlichen Klassen)
ox.requires.added = ::requires "%1" hinzugefügt; seine Klassen werden jetzt ergänzt.
ox.side.instance = Instanzseite
ox.side.class = Klassenseite
ox.showInherited = geerbte zeigen
ox.inheritedFrom = geerbt von %1 (%2)
ox.group.open.tip = Diese Mitglieder zeigen
ox.group.close.tip = Diese Mitglieder verbergen
ox.op.abuttal = (Verkettung ohne Leerzeichen)
ox.op.blank = (Verkettung mit Leerzeichen)
ox.doc.noSummary = (dokumentiert; zum Lesen klicken)
ox.doc.none = Kein ooRexxDoc für dieses Mitglied.
ox.col.name = Name
ox.col.kind = Art
ox.col.visibility = Sichtbarkeit
ox.col.guard = Schutz
ox.col.abstract = abstrakt
ox.col.definedIn = definiert in
ox.newMember = Name des neuen Mitglieds
ox.value = Wert
ox.add = Hinzufügen
ox.apply = Übernehmen
ox.removeClass = Klasse entfernen
ox.none = keine
ox.remove.tip = %1 entfernen
ox.classAdded = Klasse %1 hinzugefügt.
ox.classChanged = Klasse %1 geändert.
ox.classRemoved = Klasse %1 entfernt.
ox.memberAdded = %1 %2 hinzugefügt.
ox.memberRemoved = %1 entfernt.
ox.flags = %1: %2
ox.reloaded = (neu geladen)
ox.opened = %1 geöffnet: %2 Klassen, durch Reflexion gefunden.
ox.pickMethod = Eine Methode wählen
ox.code.placeholder = Der Rumpf der Methode.  ~ nach self, .Name, einer Variablen oder einer Zeichenkette zeigt, was sie beantwortet; . zeigt die Klassen; Strg+Leertaste überall.
ox.compiles = übersetzt
ox.saved = %1 gespeichert.
ox.copied = Kopiert.
ox.copy = Kopieren
ox.close = Schließen
-- das Fenster Bibliotheken (von Objekteditor und ooDialog Designer gemeinsam genutzt)
libs.title = Bibliotheken
libs.refresh = Von GitHub aktualisieren
libs.refresh.tip = Den Baum des Repositorys von GitHub lesen
libs.owner = Besitzer
libs.repo = Repository
libs.connect = GitHub-Repository verbinden
libs.upload = Dateien hochladen…
libs.close = Schließen
libs.filter = Filter: Logging, Mathe, …
libs.pick = Eine Bibliothek wählen.
libs.reading = %1 wird von GitHub gelesen…
libs.fromGitHub = %1 Bibliotheken, von GitHub.
libs.connected = %1 verbunden.
libs.uploaded = %1 Datei(en) zum lokalen Anbieter hinzugefügt.
libs.readingCatalogue = Der Katalog wird gelesen…
libs.file = %1 Datei
libs.files = %1 Dateien
libs.none = Nichts passt.
libs.readingOne = Wird gelesen…
libs.install = Installieren und zeigen, was sie bietet
libs.use = Hier verwenden
libs.installing = %1 und was es benötigt wird installiert…
libs.installed = %1 installiert.  Wird geladen, um zu sehen, was es bietet…
libs.subclassOf = (Unterklasse von %1)
libs.ready = Bereit: %1 öffentliche Klassen.  „Hier verwenden“ fügt das ::requires hinzu.
libs.provider.local = Dateien von diesem Computer
-- Editor und Bibliotheksanbieter lehnen ab
ox.err.noClassHere = Keine Klasse %1 in dieser Datei
ox.err.compile = Die Datei lässt sich nicht übersetzen: %1
ox.err.notDone = Nicht ausgeführt, es lässt sich nicht übersetzen: %1
ox.err.unknownClass = Hier ist keine Klasse %1 bekannt
ox.err.notClass = %1 ist keine Klasse
ox.err.name.needed = Ein Name für %1 wird gebraucht
ox.err.name.start = Ein Name für %1 beginnt mit einem Buchstaben: %2
ox.err.name.chars = Kein Name für %1: %2
ox.err.visibility = Sichtbarkeit ist public, private oder package
ox.err.guard = Schutz ist guarded oder unguarded
ox.err.classExists = Es gibt schon eine Klasse %1
ox.err.noClassHere2 = Keine Klasse %1 in dieser Datei
ox.err.memberExists = %1 hat schon %2
ox.err.noOwnSide = %1 hat kein eigenes %2 auf der %3-Seite
ox.err.constant = Eine Konstante hat keine Optionen zum Ändern
ox.err.noOwn = %1 hat kein eigenes %2
ox.err.notMethod = %1 ist keine Methode
ox.err.directive = Eine Zeile einer Methode kann nicht mit :: beginnen
ox.err.whichFile = Welche Datei?
ox.err.requiresAlready = Es benötigt %1 schon
ox.err.requiresNot = Es benötigt %1 nicht
ox.err.http = HTTP %1 für %2
ox.err.noFile = Keine Datei %1
ox.err.github = Die GitHub-API antwortete %1 für %2
ox.err.path = Kein Pfad innerhalb des Ordners: %1
ox.err.providerExists = Ein Anbieter %1 ist schon angemeldet
ox.err.noProvider = Kein Anbieter %1
ox.err.noLibrary = Keine Bibliothek %1
ox.err.notLibFile = %1 ist keine Datei von %2
ox.err.notInstalled = Nicht installiert: %1
::END
