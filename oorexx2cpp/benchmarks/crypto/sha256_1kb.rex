t = time('E')
do i = 1 to 20
  d = .SHA256~new(copies('abcdefgh', 128))~digest
end
say d
say 'sha256 20 x 1KB:' format(time('E') - t, , 2) 's'
::requires "crypto.cls"
