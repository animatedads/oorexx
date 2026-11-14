/* Person.cls -- data objects for the ooRexx Object Editor's example.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5). */
::requires "json.cls"

::class Printable public mixinclass Object
::method print
  say self~string

::class Person public
::attribute name
::attribute born
::attribute notes private
::constant KIND "person"

::method init
  expose name born notes
  use strict arg name, born = ""
  notes = .array~new

-- age in whole years, "" when born is not known
::method age
  expose born
  if born == "" then return ""
  return date("S")~left(4) - born~left(4)

::method addNote unguarded
  expose notes
  use strict arg text
  notes~append(text)

::method fromJson class
  use strict arg text
  d = .json~new~fromJson(text)
  return self~new(d["name"], d["born"])

::class Employee public subclass Person inherit Printable
::attribute salary

::method describe
  return self~name "earns" self~salary
