::Class MyList Public SubClass Array
::Class Holder Public
::Attribute list
::Method init
  expose list
  list = .MyList~new
::Method add
  expose list
  use arg i
  list~append(.Item~new(self, i))
::Method size
  expose list
  return list~items
::Class Item Public
::Attribute owner
::Attribute n
::Method init
  use strict arg self~owner, self~n
