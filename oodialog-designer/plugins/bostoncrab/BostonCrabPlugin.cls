/* BostonCrabPlugin.cls -- an optional extra for the ooDialog Designer and the
   ooRexx Object Editor: Boston Crab's ooRexx pitfall checks (P1 to P4) on the
   code being written, with the fix for P1 and P2.  The checks are Boston
   Crab's own class, RexxPitfallChecker (oorexx_slam_bostoncrab v0.23,
   tests/PitfallChecker.cls), not a copy of them.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).  German: Claude (Opus 5.5). */

::requires "OodPlugins.cls"
::requires "PitfallChecker.cls"

::class BostonCrabPlugin public subclass OodPlugin
::method module_version class
  return "0.8.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.8.0"
::method module_lastChanged
  return "2026-11-15"

::method resources
  return .resources

::method provides
  return "diagnose fix"

::method diagnose
  use strict arg lines, context = ""
  out = .array~new
  do p over .RexxPitfallChecker~new~check(lines)
    fixId = ""
    if p~fixAt > 0 then fixId = p~line":"p~fixAt
    out~append(.OodFinding~new(self~id, p~rule, p~line, p~column, "warning", self~message(p), fixId))
  end
  return out

::method message
  use strict arg p
  select
    when p~rule == "P1" then return self~nls("p1")
    when p~rule == "P2" then return self~nls("p2", p~after)
    when p~rule == "P3" then return self~nls("p3", p~names[1], p~names[2])
    otherwise return self~nls("p4", p~names[1])
  end

-- fixId: line:column of the fix, as diagnose gave it; the finding is found
-- again in these lines, so a fix is only made where it still applies
::method fix
  use strict arg lines, fixId
  parse var fixId line ":" col
  checker = .RexxPitfallChecker~new
  do p over checker~check(lines)
    if p~line = line, p~fixAt = col then return checker~fix(lines, p)
  end
  return lines

::resource strings.en
p1 = P1: a string followed at once by "(" calls a routine named by the string.  Fix: put || between them.
p2 = P2: a string followed at once by %1 is a hexadecimal or binary literal.  Fix: put || between them.
p3 = P3: %1 and %2 differ only in case, and are one name to ooRexx.
p4 = P4: the loop variable %1 overwrites the "use arg" argument of the same name.
::END

::resource strings.de
-- Deutsch: übersetzt von Claude (Opus 5.5); bitte von einem Muttersprachler prüfen
p1 = P1: eine Zeichenkette direkt vor "(" ruft eine Routine mit dem Namen der Zeichenkette auf.  Abhilfe: || dazwischen setzen.
p2 = P2: eine Zeichenkette direkt vor %1 ist ein Hexadezimal- oder Binärliteral.  Abhilfe: || dazwischen setzen.
p3 = P3: %1 und %2 unterscheiden sich nur in der Groß- und Kleinschreibung und sind für ooRexx ein Name.
p4 = P4: die Schleifenvariable %1 überschreibt das gleichnamige "use arg"-Argument.
::END
