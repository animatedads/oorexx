from pathlib import Path
import re, sys
root=Path(sys.argv[1])

for p in root.glob('*.ii'):
    k=p.stem
    t=p.read_text(errors='ignore')

    if k == 'common_Utilities_cpp':
        t=re.sub(r'\bNULL\b','0',t)

    if k == 'interpreter_behaviour_VirtualFunctionTable_cpp':
        t=re.sub(r'(?m)^\s*static_assert\s*\([^;]+\);\s*','',t)

    if k == 'interpreter_classes_EventSemaphore_cpp':
        t=t.replace('class SysSemaphore { public: SysSemaphore() {} void create() {} void close() {} void post() {} void reset() {} void wait() {} int wait(unsigned long) { return 1; } };',
                    'class SysSemaphore { public: SysSemaphore() {} void create() {} void close() {} void post() {} void reset() {} void wait() {} int wait(unsigned long) { return 1; } int posted(); };')

    if k == 'interpreter_classes_MutexSemaphore_cpp':
        t=t.replace('int request() { return 1; }\n    void release() {}',
                    'int request() { return 1; }\n    int request(uint32_t) { return 1; }\n    int requestImmediate() { return 1; }\n    int release() { return 1; }')

    # Deliberately targeted Protected<T> comparisons.  A previous broad regex
    # changed ordinary pointers and was rejected.
    protected = {
        'interpreter_classes_MessageClass_cpp': ['argPtr'],
        'interpreter_execution_BaseExecutable_cpp': ['sourceArray'],
        'interpreter_parser_InstructionParser_cpp': ['ioConfig'],
        'interpreter_instructions_DoBlockComponents_cpp': ['strResult'],
        'interpreter_parser_DirectiveParser_cpp': ['nmethod'],
        'interpreter_concurrency_TranslateDispatcher_cpp': ['fullname','program'],
        'interpreter_classes_PackageClass_cpp': ['sourceArray'],
    }
    for v in protected.get(k,[]):
        t=re.sub(r'\b'+re.escape(v)+r'\s*==\s*0\b',v+'.isNull()',t)
        t=re.sub(r'\b'+re.escape(v)+r'\s*!=\s*0\b','!'+v+'.isNull()',t)

    if k == 'interpreter_classes_StringClassMisc_cpp':
        t=t.replace('string1 += leadLength;\n    for (size_t i = 0; i < padLength; i++)\n    {\n        if (string1[i] != padChar)\n        {\n            return new_integer(leadLength + i + 1);',
                    'string1 += leadLength;\n    for (size_t j = 0; j < padLength; j++)\n    {\n        if (string1[j] != padChar)\n        {\n            return new_integer(leadLength + j + 1);')
        t=t.replace('string1 += leadLength;\n    for (size_t i = 0; i < padLength; i++)\n    {\n        if (Utilities::toUpper(string1[i]) != padChar)\n        {\n            return new_integer(leadLength + i + 1);',
                    'string1 += leadLength;\n    for (size_t j = 0; j < padLength; j++)\n    {\n        if (Utilities::toUpper(string1[j]) != padChar)\n        {\n            return new_integer(leadLength + j + 1);')

    if k == 'interpreter_classes_support_CompoundVariableTail_cpp':
        t=t.replace('tail = const_cast<char *>(t);','tail = (char *)t;')

    if k == 'interpreter_concurrency_CommandHandler_cpp':
        t=re.sub(r'MAKERXSTRING\(rxstrcmd,\s*command->getStringData\(\),\s*command->getLength\(\)\);',
                 '{ rxstrcmd.strptr = (char *)command->getStringData(); rxstrcmd.strlength = command->getLength(); }',t)
        t=t.replace('!RXNULLSTRING(retstr)','retstr.strptr != 0')
        t=re.sub(r'\bRXSUBCOM_FAILURE\b','2',t)
        t=re.sub(r'\bRXSUBCOM_ERROR\b','3',t)
        t=t.replace('RexxSubcomHandler *subcom_addr = (RexxSubcomHandler *)entryPoint;',
                    'typedef int (*MvsSubcomHandler)(PCONSTRXSTRING, unsigned short *, PRXSTRING); MvsSubcomHandler subcom_addr = (MvsSubcomHandler)entryPoint;')

    if k == 'interpreter_concurrency_RexxStartDispatcher_cpp':
        for s,v in [('RXCOMMAND','0'),('RXFUNCTION','1'),('RXSUBROUTINE','2'),('SHRT_MAX','32767'),('SHRT_MIN','(-32767-1)')]:
            t=re.sub(r'\b'+s+r'\b',v,t)
        t=re.sub(r'RXNULLSTRING\(([^\)]+)\)',r'((\1).strptr == 0)',t)
        t=t.replace('{ *result.strptr = 0; *result.strlength = 0; }','{ result->strptr = 0; result->strlength = 0; }')

    if k == 'interpreter_concurrency_TranslateDispatcher_cpp':
        t=t.replace('const_cast<char *>(source->strptr)','(char *)source->strptr')

    if k == 'interpreter_instructions_GuardInstruction_cpp':
        marker='context->traceKeywordResult(GlobalNames::WHEN, result);\n            } while (!result->truthValue(Error_Logical_value_guard));\n        }\n        for (size_t i = 0; i < variableCount; i++)\n        {\n            variables[i]->clearGuard(context);'
        repl='context->traceKeywordResult(GlobalNames::WHEN, result);\n            } while (!result->truthValue(Error_Logical_value_guard));\n        }\n        for (size_t j = 0; j < variableCount; j++)\n        {\n            variables[j]->clearGuard(context);'
        t=t.replace(marker,repl)

    if k == 'interpreter_parser_KeywordConstants_cpp':
        t=re.sub(r'static_cast<([A-Za-z_]\w*)>\((resolveKeyword\([^;]+?\))\)',r'(\1)(\2)',t)

    if k == 'interpreter_instructions_AddressInstruction_cpp':
        old='class FileNameBuffer; class SystemInterpreter { public:'
        if old in t and 'validateAddressName' not in t.split(old,1)[1].split('};',1)[0]:
            t=t.replace(old,old+' static void validateAddressName(RexxString *);',1)

    if k == 'interpreter_runtime_Version_cpp':
        if 'char *strtok(char *, const char *);' not in t:
            t='char *strtok(char *, const char *);\n'+t
        for s,v in [('ORX_VER','5'),('ORX_REL','3'),('ORX_MOD','0')]:
            t=re.sub(r'\b'+s+r'\b',v,t)

    if k == 'interpreter_instructions_InputRedirector_cpp':
        t=t.replace("class SysFileSystem { public: enum { PathDelimiter='.', PathSeparator=';' }; static int primitiveSearchName(const char *, const char *, const char *, FileNameBuffer &); static int isCaseSensitive(const char *); };",
                    "class SysFileSystem { public: enum { PathDelimiter='.', PathSeparator=';' }; static int primitiveSearchName(const char *, const char *, const char *, FileNameBuffer &); static int isCaseSensitive(const char *); static const char *EOL_Marker; };")

    if k == 'interpreter_parser_ProgramSource_cpp':
        t=t.replace('int write(const char *, size_t, size_t &); int close();',
                    'int write(const char *, size_t, size_t &); int getSize(int64_t &); int close();')

    # RexxInfo is not yet counted as a dev14 pass.  Keep only fixes that are
    # source-backed; later SysProcess/path work remains visible as the frontier.
    if k == 'interpreter_classes_RexxInfoClass_cpp':
        if 'char *strtok(char *, const char *);' not in t:
            t='char *strtok(char *, const char *);\n'+t
        for s,v in [('ORX_VER','5'),('ORX_REL','3'),('ORX_MOD','0'),('ORX_BLD','0')]:
            t=re.sub(r'\b'+s+r'\b',v,t)
        t=t.replace("class SysFileSystem { public: enum { PathDelimiter='.', PathSeparator=';' }; static int primitiveSearchName(const char *, const char *, const char *, FileNameBuffer &); static int isCaseSensitive(const char *); };",
                    "class SysFileSystem { public: enum { PathDelimiter='.', PathSeparator=';', MaximumPathLength=1024 }; static int primitiveSearchName(const char *, const char *, const char *, FileNameBuffer &); static int isCaseSensitive(); static int isCaseSensitive(const char *); static const char *getLineEnd(); static const char *getSeparator(); static const char *getPathSeparator(); };")
        t=t.replace('class FileNameBuffer; class SystemInterpreter { public:', 'class FileNameBuffer; class SystemInterpreter { public: static const char *getPlatformName();',1)
        t=t.replace('GlobalNames::struct _iobuf','GlobalNames::FILE')


    # Protected<T>::mark cannot be instantiated while objType is incomplete in
    # old cfront.  Defer the two bodies in the affected package/runtime TUs.
    if k in {
      'interpreter_execution_NativeCode_cpp','interpreter_memory_Setup_cpp',
      'interpreter_package_LibraryPackage_cpp','interpreter_package_PackageManager_cpp',
      'interpreter_runtime_InternalPackage_cpp','interpreter_runtime_RexxUtilCommon_cpp',
      'interpreter_runtime_Interpreter_cpp'}:
        t=t.replace('void mark(size_t liveMark) { if (((protectedObject) != 0 && !((protectedObject)->isObjectMarked(liveMark)) )) memoryObject.mark(protectedObject); }','void mark(size_t liveMark);')
        t=t.replace('void markGeneral(int reason) { (memoryObject.markGeneral((void *)&(protectedObject))); }','void markGeneral(int reason);')

    compact_fb='class FileNameBuffer { public: FileNameBuffer(size_t initial=0); FileNameBuffer(const char *); FileNameBuffer(const FileNameBuffer &); ~FileNameBuffer(); FileNameBuffer &operator=(const char *); FileNameBuffer &operator+=(const char *); operator char *(); operator const char *(); protected: char *buffer; size_t bufferSize; };'
    if k in {'interpreter_memory_FileNameBuffer_cpp','interpreter_runtime_InternalPackage_cpp','interpreter_runtime_RexxUtilCommon_cpp','interpreter_streamLibrary_StreamNative_cpp'}:
        rest=t[t.find(compact_fb)+len(compact_fb):] if compact_fb in t else ''
        if compact_fb in t and re.search(r'class\s+FileNameBuffer\s*\n?\s*\{',rest):
            t=t.replace(compact_fb,'class FileNameBuffer;',1)

    if k == 'interpreter_execution_NativeCode_cpp':
        t=t.replace('entry = PackageManager::resolveRegisteredRoutineEntry(packageName, name);',
                    'entry = (RexxRoutineHandler *)PackageManager::resolveRegisteredRoutineEntry(packageName, name);')

    if k == 'interpreter_package_PackageManager_cpp':
        marker='RoutineClass *PackageManager::resolveRoutine(RexxString *function, RexxString *packageName, RexxString *procedure)'
        decl='int RexxRegisterFunctionDll(const char *, const char *, const char *);\nint RexxDeregisterFunction(const char *);\nint RexxQueryFunction(const char *);\n'
        if marker in t and decl not in t:
            t=t.replace(marker,decl+marker,1)
        t=re.sub(r'\bRXMACRO_SEARCH_BEFORE\b','1',t)

    p.write_text(t)
