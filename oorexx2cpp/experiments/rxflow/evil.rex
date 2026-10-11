s = .stream~new('/home/claude/EVIL_methodpath.txt')
s~lineout('written through a stream object')
s~close
f = .File~new('/home/claude/EVIL_file.txt')
call lineout '/home/claude/EVIL_bif.txt', 'x'
say 'attempted'
