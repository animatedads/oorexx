/* People.cls -- the classes of the bound example (examples/People.rex): a
   Person over five tables of the database ent, as oorexx_mapped_objects maps
   them.  Tom Dyer's example: a Person from ent.per, its addresses from
   ent.addr through the link table ent.per_addr.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5). */

::class Person public
::annotate class Person table "ent.per" key "per_id" generate "max"
::attribute id
::annotate attribute id column "per_id"
::attribute name
::annotate attribute name column "per_name"
::attribute phone
::annotate attribute phone column "phone" table "ent.per_ext"
::attribute active
::annotate attribute active column "per_active"
::attribute addresses
::annotate attribute addresses many "Address" link "ent.per_addr" from "per_id" to "addr_id"
::attribute notes
::annotate attribute notes many "Note" column "per_id"
::attribute employer
::annotate attribute employer one "Company" column "per_company"

::class Address public
::annotate class Address table "ent.addr" key "addr_id" generate "max"
::attribute street
::annotate attribute street column "addr_street"
::attribute town
::annotate attribute town column "addr_town"

::class Note public
::annotate class Note table "ent.note" key "note_id" generate "max"
::attribute text
::annotate attribute text column "note_text"

::class Company public
::annotate class Company table "ent.com" key "com_id"
::attribute name
::annotate attribute name column "com_name"
