/* ooShapes.cls for ooRexx/WASM: .Point, .Size and .Rect in Rexx.
 * On Windows these classes are native (the ooShapes library); ooDialog.cls
 * requires them.  Architecture: Tom Dyer.  Code: Claude (Fable 5.2). */

::class 'Point' public
::method module_version class
  return "0.1.0"
::method module_lastChanged class
  return "2026-11-14"
::attribute x unguarded
::attribute y unguarded
::method init
  expose x y
  use strict arg x = 0, y = (x)
::method copy unguarded
  expose x y
  return .Point~new(x, y)
::method "+" unguarded
  expose x y
  use strict arg other
  if other~isA(.Size) then return .Point~new(x + other~width, y + other~height)
  return .Point~new(x + other~x, y + other~y)
::method "-" unguarded
  expose x y
  use strict arg other
  if other~isA(.Size) then return .Point~new(x - other~width, y - other~height)
  return .Point~new(x - other~x, y - other~y)
::method incr unguarded
  expose x y
  use strict arg dx = 1, dy = (dx)
  x = x + dx
  y = y + dy
::method decr unguarded
  expose x y
  use strict arg dx = 1, dy = (dx)
  x = x - dx
  y = y - dy
::method inRect unguarded
  expose x y
  use strict arg r
  if x < r~left then return .false
  if x >= r~right then return .false
  if y < r~top then return .false
  if y >= r~bottom then return .false
  return .true
::method string unguarded
  expose x y
  return "a Point (" || x || "," y || ")"

::class 'Size' public
::method module_version class
  return "0.1.0"
::method module_lastChanged class
  return "2026-11-14"
::attribute width unguarded
::attribute height unguarded
::method init
  expose width height
  use strict arg width = 0, height = (width)
::method copy unguarded
  expose width height
  return .Size~new(width, height)
::method "=" unguarded
  expose width height
  use strict arg other
  if \other~isA(.Size) then return .false
  if width \= other~width then return .false
  return height = other~height
::method string unguarded
  expose width height
  return "a Size (" || width || "," height || ")"

::class 'Rect' public
::method module_version class
  return "0.1.0"
::method module_lastChanged class
  return "2026-11-14"
::attribute left unguarded
::attribute top unguarded
::attribute right unguarded
::attribute bottom unguarded
::method init
  expose left top right bottom
  use strict arg left = 0, top = (left), right = (left), bottom = (left)
::method copy unguarded
  expose left top right bottom
  return .Rect~new(left, top, right, bottom)
::method string unguarded
  expose left top right bottom
  return "a Rect (" || left || "," top || "," right || "," bottom || ")"
