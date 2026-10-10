-- Instantiate developer objects
dev1 = .Developer~new("101", "Thomas Dyer", "Systems Architect")
dev1~addSkill("ooRexx")
dev1~addSkill("C++")
dev1~addSkill("Linux")

dev2 = .Developer~new("102", "Alex Mercer", "Infrastructure Engineer")
dev2~addSkill("Python")
dev2~addSkill("SQL")
dev2~addSkill("Bash")

-- Standard ooRexx Array collection
team = .Array~of(dev1, dev2)

say "=== Developer Registry ==="
say

-- Loop over objects in the collection
loop dev over team
    dev~display
    say "-"~copies(40)
end

exit

/* -------------------------------------------------------------------------- */
::class Developer

::attribute id
::attribute name
::attribute role
::attribute skills

-- Constructor / Initializer
::method init
  expose id name role skills
  use arg id, name, role
  skills = .Array~new

-- Instance Methods
::method addSkill
  expose skills
  use arg skill
  skills~append(skill)

::method display
  expose id name role skills
  say "ID    :" id
  say "Name  :" name
  say "Role  :" role
  say "Skills :" skills~makeString("L", ", ")
