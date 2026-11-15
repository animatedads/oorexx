::requires "Inner.cls"
::class Helper public
::method answer
  return "helper sees" .Inner~new~value
