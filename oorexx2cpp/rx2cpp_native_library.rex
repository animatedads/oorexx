/* Source-defined ooRexx PUBLIC classes to one native extension library.
   Both package parsing and code-generation are implemented in ooRexx. */
parse arg input prefix packageName
if input == '' | prefix == '' | packageName == '' then do
  say 'Usage: rexx rx2cpp_native_library.rex classes.cls output-prefix package-name'
  exit 64
end
signal on syntax name compilerError
signal on error name compilerError
signal on failure name compilerError
source = readSource(input)
extras = .RxNativePackageExtras~new~parse(source)
source = extras~sanitized
routines = .RxNativePackageRoutines~new~parse(source)
source = routines~sanitized
gateOK = .RxNativeSourceGate~new~validate(source)
parser = .RxNativePackageParser~new
units = parser~parse(source)
extras~validate(units)
if routines~implementation \= .nil then do
  do unit over units
    if unit~className == 'RX2CPP_ROUTINE_IMPL' then
      raise syntax 40.1 array('rx2cpp: reserved internal routine implementation class name')
  end
end
options = parser~options
template = readSource('native/native_package_template.cpp.in')
emitter = .RxNativeLibraryEmitter~new
nativeSource = emitter~emitPackage(units, packageName, template, options, extras~suffix, routines)
cpp = ''
header = '#ifndef RX2CPP_GENERATED_HPP' || '0a'x || ,
         '#define RX2CPP_GENERATED_HPP' || '0a'x || ,
         '#include "compiled_registry.hpp"' || '0a'x || ,
         '#include <memory>' || '0a'x || ,
         'namespace rx2cpp {' || '0a'x
names = ''
if routines~implementation \= .nil then do
  routineUnit = routines~implementation
  cpp = cpp || .RxHybridCppEmitter~new~emit(routineUnit, .false, options)
  header = header || 'std::shared_ptr<CompiledObject> makeGeneratedObject_RX2CPP_ROUTINE_IMPL();' || '0a'x
end
do unit over units
  cpp = cpp || .RxHybridCppEmitter~new~emit(unit, .false, options)
  header = header || 'std::shared_ptr<CompiledObject> makeGeneratedObject_' || unit~className || '();' || '0a'x
  names = names || unit~className || ' '
end
header = header || '}' || '0a'x || '#endif' || '0a'x
/* All parsing and validation completes before writing generated output. */
call writeOutput prefix || '.hpp', header
call writeOutput prefix || '.cpp', cpp
call writeOutput prefix || '_package.cpp', nativeSource
say 'rx2cpp native package compiled' names~strip 'classes='units~items
exit 0
readSource:
  use arg path
  if stream(path, 'C', 'QUERY EXISTS') == '' then raise syntax 40.1 array('rx2cpp: source missing ' || path)
  content = charin(path, 1, chars(path))
  call stream path, 'C', 'CLOSE'
  return content
writeOutput:
  use arg filename, contents
  state = stream(filename, 'C', 'OPEN WRITE REPLACE')
  if left(state, 6) \= 'READY:' then raise syntax 40.1 array('rx2cpp: cannot write ' || filename)
  call charout filename, contents
  call stream filename, 'C', 'CLOSE'
  return
compilerError:
  say 'rx2cpp: native package compile failed:' condition('O')~at('MESSAGE')
  exit 65
::requires 'hybrid/compiler/RxHybridCppEmitter.cls'
::requires 'native/NativeLibraryEmitter.cls'
::requires 'native/NativePackageParser.cls'
::requires 'native/NativeSourceGate.cls'
::requires 'native/NativePackageExtras.cls'
::requires 'native/NativePackageRoutines.cls'
