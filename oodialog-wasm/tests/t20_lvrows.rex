/* t20: LvItem, LvSubItem, LvFullRow and the list-view methods that use them. */
dlg = .Main~new
dlg~create(30, 30, 260, 150, "Rows", "CENTER")
dlg~execute("SHOWTOP")
return 0

::requires "ooDialog.cls"

::class Main subclass UserDialog
::method defineDialog
  self~createListView(100, 5, 5, 250, 110, "REPORT")
  self~createPushButton(201, 5, 125, 60, 14, , "Sort by age", onSort)
  self~createPushButton(202, 70, 125, 60, 14, , "Sort by data", onData)
  self~createPushButton(1, 205, 125, 50, 14, "DEFAULT", "Close")
::method initDialog
  list = self~newListView(100)
  list~insertColumn(0, "Name", 70)
  list~insertColumn(1, "Town", 70)
  list~insertColumn(2, "Age", 40)

  item = .LvItem~new(0, "Mike", 3, "data-mike")
  say "item" item~index item~text item~imageIndex item~itemData "mask" item~mask
  row = .LvFullRow~new(item, .LvSubItem~new(0, 1, "Perth", 7), .LvSubItem~new(0, 2, "41"), .true)
  say "row" row~subitems row~subitem(1)~text row~subitem(2)~text (row~subitem(3) == .nil) row~item~text
  say "add" list~addFullRow(row)
  say "add" list~addFullRow(.LvFullRow~fromArray(.array~of("Sue", .nil, 9), , "?"))
  first = .LvFullRow~fromArray(.array~of("Ann", "Oban", 30))
  say "prepend" list~prependFullRow(first) "its item is now at" first~item~index
  at1 = .LvFullRow~new(.LvItem~new(1, "Bob"), .LvSubItem~new(1, 1, "Ayr"))
  say "extra" at1~addSubitem(.LvSubItem~new(1, 9, "25")) at1~subitem(2)~subItem
  say "insert" list~insertFullRow(at1)
  say "array" list~addRowFromArray(.array~of("Zed", "Wick", 5))
  say "rows" self~rows(list)

  got = list~getFullRow(2)
  say "got" got~item~text got~item~imageIndex (got~item~itemData == row) got~subitem(1)~text got~subitem(1)~imageIndex got~subitem(2)~text got~subitems
  say "none" (list~getFullRow(99) == .nil)
  sub = .LvSubItem~new(3, 1)
  say "getSubitem" list~getSubitem(sub) sub~text "new:" list~getSubitem(0, 2)~text
  say "modifyItem" list~modifyItem(.LvItem~new(3, "Susan", , "data-sue")) list~itemText(3) list~getItemData(3)
  say "modifySubitem" list~modifySubitem(.LvSubItem~new(3, 1, "Elgin")) list~itemText(3, 1)
  got~item~text = "Michael"
  got~subitem(1)~text = "Perth WA"
  say "setFullRowText" list~setFullRowText(got) list~itemText(2) "/" list~itemText(2, 1)
  say "state" list~setItemState(4, "SELECTED FOCUSED") list~selected list~focused
  removed = at1~removeSubitem(1)
  say "removed" removed~text at1~subitems at1~subitem(1)~text at1~subitem(1)~subItem
  say "insertSubitem" at1~insertSubitem(.LvSubItem~new(1, 1, "Troon"), 1) at1~subitem(1)~text at1~subitem(2)~text at1~subitem(2)~subItem
  at1~userData = "u"
  say "userData" at1~userData
  self~list = list
::attribute list
::method rows
  use arg list
  text = ""
  do i = 0 to list~items - 1
    text = text list~itemText(i)"/"list~itemText(i, 1)"/"list~itemText(i, 2)
  end
  return text~strip
::method onSort unguarded
  d = .directory~new
  d~column = 2
  d~ascending = .false
  say "sorted" self~list~sortItems("InternalListViewSort", d) self~rows(self~list)
  say "data follows its row:" self~list~getItemData(self~list~find("Susan"))
::method onData unguarded
  do i = 0 to self~list~items - 1
    self~list~setItemData(i, self~list~itemText(i)~length)     -- the length of the name
  end
  say "by data" self~list~sortItems("byLength", "p") self~rows(self~list)
::method byLength unguarded
  use arg left, right, param
  if param \== "p" then return 0
  return sign(left - right)
