::class cnode public
::attribute next
::attribute prev
::attribute payload
::attribute kids
::method init
  expose payload kids next prev
  next = .nil; prev = .nil
  use arg payload
  kids = .array~new
::method addKid
  expose kids
  use arg k
  kids~append(k)
  k~prev = self
::class tracked public
::attribute other
::method uninit
  nop
