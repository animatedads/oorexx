a = .Leaf~new('parent')
say a~rootValue
say a~branchValue
say a~leafValue
say a~shared
say a~isA(.Root)
say a~isA(.Branch)
a~branchSet('middle')
a~leafSet('lower')
say a~rootValue
say a~branchValue
say a~leafValue
say a~rootSet('top')
say a~rootValue
say a~branchValue
say a~leafValue
b = .Leaf~new('second')
say b~rootValue
say b~branchValue
say b~leafValue
::requires 'rx2cpp_inherit' library
