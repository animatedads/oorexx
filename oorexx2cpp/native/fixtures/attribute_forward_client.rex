p=.Parcel~new
say 'unset' p~thing
p~thing='abc'
say 'after' p~thing p~alias p~alias2
p~thing='xyz'
say 'again' p~alias

::requires 'rx2cpp_objattribute' library
