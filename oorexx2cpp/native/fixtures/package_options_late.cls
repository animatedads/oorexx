/* Package options are not positional: last applicable setting wins. */
::class Before public
::method init
::method digitsValue
  return 1 / 3
::options digits 12
::class After public
::method init
::method digitsValue
  return 1 / 3
::options digits 25 form engineering
::options digits 18
