/* ADDRESS environment command in a compiled library: the interpreter runs the command; RC, output and the
   variable named ADDRESS behave as interpreted. */
::class AddressCommand public
::method init
::method run
  say 'default' address()
  command = "echo hello from the shell"
  address system command
  say 'rc' rc
  address system "exit 3"
  say 'rc' rc
  address system 'printf "%s|%s\n" a b'
  say 'rc' rc
  address = 5
  address += 1
  say 'variable' address
  address value 'SYSTEM'
  say 'now' address()
  return rc
