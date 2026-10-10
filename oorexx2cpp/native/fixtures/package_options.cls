/* Tricky numeric setting: must be initialized in the CLASS backend's C++
   method activation and in the interpreter-loaded source declaration. */
::options digits 9 form scientific fuzz 0
::options digits 25 form scientific
::options form scientific form engineering fuzz 1
::class OptionsProbe public
::method init
::method large
  return 12345678901234567890 + 1
::method small
  return 1000 / 3
::method scientific
  return 1 / 100000000000000000000000000000
::method fuzzy
  return 1.0000000000000000000000000 = 1.0000000000000000000000001
