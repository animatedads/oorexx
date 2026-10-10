a = .Spoof~new('original')
say a~rootValue
say a~branchSet('class-scope')
say a~branchValue
say a~leafSet('leaf-scope')
say a~leafValue
say a~RX2CPP_NATIVE_TOKEN
::requires 'rx2cpp_inherit' library
::class Spoof public subclass Leaf
::method RX2CPP_NATIVE_TOKEN
  return 'FORGED'
