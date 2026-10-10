::class Widget public
::method init
::attribute both
::attribute readOnly GET
::attribute writeOnly SET
::constant TAG 'it''s a constant'
::constant NUMBER 42
::constant SYMBOL Literal
::constant EMPTY ''
::constant BARE
::method inspectSetter
  expose writeOnly
  return writeOnly
::method initialiseGetter
  expose readOnly
  use arg val
  readOnly = val
  return readOnly
