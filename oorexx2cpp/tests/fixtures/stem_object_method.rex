data.1 = "Original"
worker = .Worker~new
worker~modify(data.)
say data.1
worker~replace(data.)
say data.1
exit
::class Worker
::method modify
  use arg s.
  s.1 = "Changed"
::method replace
  use arg s.
  s. = .stem~new
  s.1 = "Replacement"
