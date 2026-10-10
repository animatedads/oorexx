 say .MetaWidget~tag
 say .MetaWidget~negative
 say .MetaWidget~new~negative
 say .MetaWidget~new~greet
 p = .MetaWidget~package
 say p~trace
 say p~annotations~at('AUTHOR')
 say .MetaWidget~annotations~at('OBJECT')
 say p~resource('PAYLOAD')[1]
 say p~resource('PAYLOAD')[2]
 say p~resource('SECOND ITEM')[1]
 say p~resource('SECOND ITEM')[2]
 say p~resource('COMMENTED') == .nil
 say p~findNamespace('EXT')~findClass('EXTERNTHING')~new~marker
 ::requires 'native_extras.cls'
