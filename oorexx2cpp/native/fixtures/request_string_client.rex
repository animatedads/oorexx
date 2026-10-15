say .Requests~new~run(.ByRequest~new, .NoString~new, .ByMake~new)
exit
::class ByRequest
::method request
  if arg(1) == 'STRING' then return 'from REQUEST'
  return .nil
::method makestring
  return 'from MAKESTRING (not used)'
::class NoString
::method string
  return 'a NoString object'
::class ByMake
::method makestring
  return 'from MAKESTRING'
