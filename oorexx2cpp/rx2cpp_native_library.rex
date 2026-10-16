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
progress = value('RX2CPP_PROGRESS', , 'ENVIRONMENT') == '1'
call time 'R'
source = readSource(input)
extras = .RxNativePackageExtras~new~parse(source)
source = extras~sanitized
.local['RX2CPP.INPUTNAME'] = input   /* PARSE SOURCE of a routine outside any combine marker */
routines = .RxNativePackageRoutines~new~parse(source)
source = routines~sanitized
/* A package of routines only (no ::CLASS): a private class of no use stands in for the class the native package needs. */
if routines~names~items > 0 | routines~externalDeclarations~items > 0 then do
  hasClass = .false
  scanned = .RxLexer~new(source)~scan          /* (comments and strings are not directives) */
  do k = 1 to scanned~items - 1
    if scanned[k]~text == '::' & scanned[k]~kind == 'OP' & scanned[k+1]~text~upper == 'CLASS' then do
      hasClass = .true
      leave
    end
  end
  if \hasClass then source = source || '0a'x || '::class RX2CPP_ROUTINES_ONLY' || '0a'x
end
gateOK = .RxNativeSourceGate~new~validate(source)
parser = .RxNativePackageParser~new
parser~inputName = input
parser~setRequiredElsewhere(extras~suffix~caselessPos('::requires') > 0)
/* Interpreted table (RX2CPP_TABLE, set by native/build.sh): classes / methods the interpreter runs. */
table = .RxNativeInterpretedTable~new(value('RX2CPP_TABLE', , 'ENVIRONMENT'))
if progress then .error~lineout('rx2cpp: progress' time('E')~format(, 1)'s source scanned')
units = parser~parse(source, table)
if progress then .error~lineout('rx2cpp: progress' time('E')~format(, 1)'s parsed' units~items 'classes')
table~report
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
emitter~interpretedMethods = parser~interpretedMethods
emitter~interpretedPublic = parser~interpretedPublic
emitter~form = table~form
emitter~workPrefix = prefix
emitter~floating = parser~floating
if table~form == 'file' then do
  /* The interpreted parts go to an editable file read when the library loads; the declaration keeps marker lines. */
  suffix = extras~suffix
  if parser~interpretedSource \== '' then suffix = suffix || '/* #REXX2CPP CLASSES */' || '0a'x
  editable = '/* Interpreted parts of native library' packageName'. Read every time the library loads: edit freely,' || '0a'x || ,
             '   but keep the /* #REXX2CPP ... */ marker lines; each says where the code below it belongs. */' || '0a'x
  do className over parser~interpretedMethods~allIndexes~sortWith(.CaselessComparator~new)
    editable = editable || '/* #REXX2CPP METHODS' className '*/' || '0a'x || parser~interpretedMethods[className]
  end
  if parser~interpretedSource \== '' then editable = editable || '/* #REXX2CPP CLASSES */' || '0a'x || parser~interpretedSource
end
else suffix = extras~suffix || parser~interpretedSource
/* The package prolog runs once, interpreted, when the library is loaded (see loadPackage in the template). */
if parser~prolog \== '' then suffix = suffix || '::routine RX2CPP_PACKAGE_PROLOG' || '0a'x || parser~prolog
nativeSource = emitter~emitPackage(units, packageName, template, options, suffix, routines)
if progress then .error~lineout('rx2cpp: progress' time('E')~format(, 1)'s package glue emitted')
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
  if progress then .error~lineout('rx2cpp: progress' time('E')~format(, 1)'s emitted' unit~className '('cpp~length 'bytes so far)')
  header = header || 'std::shared_ptr<CompiledObject> makeGeneratedObject_' || .RxQuote~identifier(unit~className) || '();' || '0a'x
  names = names || unit~className || ' '
end
/* SOURCELINE: the lines of each source file it reads, embedded (split as the interpreter does: LF, a CR before it
   dropped; a final line end adds no line). */
files = .local['RX2CPP.SOURCEFILES']
if files~isA(.array) then if files~items > 0 then do
  header = header || '}' || '0a'x || '#include <string>' || '0a'x || '#include <vector>' || '0a'x || 'namespace rx2cpp {' || '0a'x
  header = header || 'const std::vector<std::string> &sourceLines(int id);' || '0a'x
  cpp = cpp || 'namespace rx2cpp {' || '0a'x || 'const std::vector<std::string> &sourceLines(int id) {' || '0a'x
  do id = 1 to files~items
    fileLines = readSource(files[id])~makeArray('0a'x)
    body = .mutableBuffer~new
    do oneLine over fileLines
      if oneLine~right(1) == '0d'x then oneLine = oneLine~left(oneLine~length - 1)
      body~append(.RxQuote~cpp(oneLine), ', ')
    end
    cpp = cpp || '    static const std::vector<std::string> file' || id || ' = {' || body~string || '};' || '0a'x || '    if (id == ' || id || ') return file' || id || ';' || '0a'x
  end
  cpp = cpp || '    static const std::vector<std::string> none;' || '0a'x || '    return none;' || '0a'x || '}' || '0a'x || '}' || '0a'x
end
header = header || '}' || '0a'x || '#endif' || '0a'x
/* All parsing and validation completes before writing generated output. */
call writeOutput prefix || '.hpp', header
call writeOutput prefix || '.cpp', cpp
call writeOutput prefix || '_package.cpp', nativeSource
if table~form == 'file' then call writeOutput prefix || '_interpreted.cls', editable
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
::requires 'native/NativeInterpretedTable.cls'
