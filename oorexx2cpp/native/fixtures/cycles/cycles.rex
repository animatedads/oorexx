/* cyclic structures of compiled objects: a doubly linked list, parents and children in arrays, objects kept
   by the interpreter across the collections, a class with UNINIT */
keep = .array~new
total = 0
do pass = 1 to 6
  first = .cnode~new('head' pass); last = first
  do i = 1 to 3000
    n = .cnode~new(i)
    last~next = n; n~prev = last; last = n
    if i // 3 = 0 then last~addKid(.cnode~new('kid' i))
    if pass = 1 & i // 500 = 0 then keep~append(n)   /* kept: this list survives, with its neighbours */
  end
  t = .tracked~new; u = .tracked~new; t~other = u; u~other = t
  /* walk the list */
  c = 0; x = first
  do while x \== .nil; c += 1; x = x~next; end
  total += c
  first = .nil; last = .nil; n = .nil
end
say 'walked' total
/* the kept nodes and what they reach are intact */
do k over keep
  nx = k~next; if nx \== .nil then nx = nx~payload
  say k~payload k~prev~payload nx k~kids~items
end
::requires 'cnodes.cls'
