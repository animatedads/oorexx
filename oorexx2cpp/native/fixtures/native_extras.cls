/*
::resource COMMENTED
::END
*/
::annotate package AUTHOR 'rx2cpp'
::options noprolog trace off
::class MetaWidget public
::method init
::method greet
  return 'hello'
::constant TAG 'constant-value'
::constant NEGATIVE -273.15
::annotate class MetaWidget OBJECT 'true'
::annotate method greet AUTHOR 'rule'
::annotate constant TAG TYPE 'label'
::requires 'native_extras_dependency.cls' namespace EXT
::resource PAYLOAD
Hello from the resource.
::class this must not be parsed as a class
::END
::resource 'SECOND ITEM' end TERMINATE
  Two leading spaces remain in data
; semicolon and ::constant are raw resource data
TERMINATE
