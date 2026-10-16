ia = .array~new(3); ia[1] = 'one'
md = .array~new(2, 2); md[1, 2] = 'md12'
sub = .Shout~of('a', 'b', 'c')
say .CollectionPaths~new~run(ia, md, sub)
say ia~size ia[5] ia[1]~class~id
exit
::class Shout subclass Array
::method '[]'
  forward class (super) continue
  return result~upper
