from pathlib import Path
import re,sys
root=Path(sys.argv[1])
FILEBUF_UNITS={'interpreter_memory_FileNameBuffer_cpp','interpreter_runtime_InternalPackage_cpp','interpreter_runtime_RexxUtilCommon_cpp','interpreter_streamLibrary_StreamNative_cpp'}
fb_assign='''inline FileNameBuffer &operator=(const FileNameBuffer &s)\n     {\n         if (this == &s)\n         {\n             return *this;\n         }\n         const char *str = (const char *)s.buffer;\n         ensureCapacity(strlen(str));\n         strncpy(buffer, str, bufferSize);\n         return *this;\n     }'''
fb_starts='''inline int startsWith(const char *s)\n     {\n         size_t slen = strlen(s);\n         size_t len = length();\n         if (slen > len)\n         {\n             return 0;\n         }\n         return strncmp(buffer, s, slen) == 0;\n     }'''
fb_ends='''inline int endsWith(const char *s)\n     {\n         size_t slen = strlen(s);\n         size_t len = length();\n         if (slen > len)\n         {\n             return 0;\n         }\n         return strcmp(buffer + (len - slen), s) == 0;\n     }'''

def flatten_parse_action(t):
    t=t.replace('''int_output = &target;\n        int_value = source;\n        bool_output = 0;\n        bool_value = 0;''','''int_output = &target;\n        int_value = source;\n        bool_output = &target;\n        bool_value = source;''',1)
    t=t.replace('''int_output = &target;\n        int_value = 0;\n        bool_output = 0;\n        bool_value = 0;''','''int_output = &target;\n        int_value = 0;\n        bool_output = &target;\n        bool_value = 0;''',1)
    pat=r'''\n    inline ParseAction\(ActionType a, int &target, int source\)\n    \{\n        action = a;\n        bool_output = &target;\n        bool_value = source;\n        int_output = 0;\n        int_value = 0;\n        afp = 0;\n        actionParm = 0;\n    \}\n    inline ParseAction\(ActionType a, int &target\)\n    \{\n        action = a;\n        bool_output = &target;\n        bool_value = 0;\n        int_value = 0;\n        int_output = 0;\n        afp = 0;\n        actionParm = 0;\n    \}'''
    return re.sub(pat,'',t,count=1)

for p in root.glob('*.ii'):
    k=p.stem; t=p.read_text(errors='ignore')

    if k in FILEBUF_UNITS:
        t=t.replace("class SysFileSystem { public: enum { PathDelimiter='.', PathSeparator=';' }; static int primitiveSearchName(const char *, const char *, const char *, FileNameBuffer &); static int isCaseSensitive(const char *); };",
                    "class SysFileSystem { public: enum { PathDelimiter='.', PathSeparator=';', MaximumPathLength=1024 }; static int primitiveSearchName(const char *, const char *, const char *, FileNameBuffer &); static int isCaseSensitive(const char *); static const char *getPathSeparator(); static void qualifyStreamName(const char *, FileNameBuffer &); };")
        t=t.replace(fb_assign,'FileNameBuffer &operator=(const FileNameBuffer &s);')
        t=t.replace(fb_starts,'int startsWith(const char *s);')
        t=t.replace(fb_ends,'int endsWith(const char *s);')
        if k=='interpreter_memory_FileNameBuffer_cpp':
            defs='''\nFileNameBuffer &FileNameBuffer::operator=(const FileNameBuffer &s) { if (this != &s) { const char *str=(const char *)s.buffer; ensureCapacity(strlen(str)); strncpy(buffer,str,bufferSize); } return *this; }\nint FileNameBuffer::startsWith(const char *s) { size_t slen=strlen(s); size_t len=length(); return slen <= len && strncmp(buffer,s,slen)==0; }\nint FileNameBuffer::endsWith(const char *s) { size_t slen=strlen(s); size_t len=length(); return slen <= len && strcmp(buffer+(len-slen),s)==0; }\n'''
            marker='class QualifiedName\n'
            if marker in t and 'FileNameBuffer::startsWith(const char *s)' not in t: t=t.replace(marker,defs+marker,1)

    if k=='interpreter_classes_RexxInfoClass_cpp':
        t=t.replace('class SysProcess { public: SysProcess() {} static const char *getLibraryLocation(); };','class SysProcess { public: SysProcess() {} static const char *getLibraryLocation(); static const char *getExecutableFullPath(); };')

    if k=='interpreter_classes_PackageClass_cpp':
        t=t.replace("class SysFileSystem { public: enum { PathDelimiter='.', PathSeparator=';' }; static int primitiveSearchName(const char *, const char *, const char *, FileNameBuffer &); static int isCaseSensitive(const char *); };",
                    "class SysFileSystem { public: enum { PathDelimiter='.', PathSeparator=';' }; static int primitiveSearchName(const char *, const char *, const char *, FileNameBuffer &); static int isCaseSensitive(const char *); static RexxString *extractDirectory(RexxString *); static RexxString *extractExtension(RexxString *); static RexxString *extractFile(RexxString *); };")
        needle='''for (size_t i = 1; i <= count; i++)\n        {\n            ClassDirective *current_class = (ClassDirective *)classes->get(i);\n            current_class->install(this, activation);\n        }\n        for (size_t i = 1; i <= count; i++)\n        {\n            ClassDirective *current_class = (ClassDirective *)classes->get(i);\n            current_class->resolveConstants(this, activation->getActivity());\n        }\n        for (size_t i = 1; i <= count; i++)\n        {\n            ClassDirective *current_class = (ClassDirective *)classes->get(i);\n            current_class->activate();\n        }'''
        repl='''for (size_t classInstall = 1; classInstall <= count; classInstall++)\n        {\n            ClassDirective *current_class = (ClassDirective *)classes->get(classInstall);\n            current_class->install(this, activation);\n        }\n        for (size_t classResolve = 1; classResolve <= count; classResolve++)\n        {\n            ClassDirective *current_class = (ClassDirective *)classes->get(classResolve);\n            current_class->resolveConstants(this, activation->getActivity());\n        }\n        for (size_t classActivate = 1; classActivate <= count; classActivate++)\n        {\n            ClassDirective *current_class = (ClassDirective *)classes->get(classActivate);\n            current_class->activate();\n        }'''
        t=t.replace(needle,repl)
        t=t.replace('Rexx_Error_Invalid_whole_number_user_defined','Error_Invalid_whole_number_user_defined')
        t=t.replace('Rexx_Error_Incorrect_method_null','Error_Incorrect_method_null')
        t=re.sub(r'char\s+([A-Za-z_]\w*)\[([^\]]+)\]\s*=\s*""\s*;',r'char \1[\2]; \1[0] = 0;',t)

    if k=='interpreter_expression_BuiltinFunctions_cpp':
        t=t.replace('inline RexxString *checkPadArgument(','RexxString *checkPadArgument(',1)
        t=t.replace('if (retriever == 0 || (newvalue != 0 && !assignable))','if (retriever.isNull() || (newvalue != 0 && !assignable))')
        t=t.replace('if (result == 0)\n        {\n            result = variable->upper()->concatToCstring(".");','if (result.isNull())\n        {\n            result = variable->upper()->concatToCstring(".");')
        t=t.replace('static int getEnvironmentVariable(const char *, FileNameBuffer &); };','static int getEnvironmentVariable(const char *, FileNameBuffer &); static int setEnvironmentVariable(const char *, const char *); static int valueFunction(RexxString *, RexxObject *, RexxString *, ProtectedObject &); static RexxString *getUserid(); static RexxObject *pushEnvironment(RexxActivation *); static RexxObject *popEnvironment(RexxActivation *); };')
        if 'class QualifiedName' not in t:
            marker='class SysLibrary { public: SysLibrary() {} };'
            t=t.replace(marker,'class QualifiedName { public: QualifiedName(const char *); operator const char *(); protected: FileNameBuffer qualifiedName; };\n'+marker,1)

    if k=='interpreter_instructions_ParseTarget_cpp':
        t=t.replace('FlagSet32_translate, int multiple','FlagSet32 _translate, int multiple')

    if k in {'interpreter_streamLibrary_StreamCommandParser_cpp','interpreter_streamLibrary_StreamNative_cpp'}:
        t=flatten_parse_action(t)

    if k=='interpreter_concurrency_ExitHandler_cpp':
        if 'typedef int RexxExitHandler(int, int, PEXIT);' not in t:
            t=t.replace('typedef int RexxContextExitHandler(RexxExitContext *, int, int, PEXIT);','typedef int RexxExitHandler(int, int, PEXIT);\ntypedef int RexxContextExitHandler(RexxExitContext *, int, int, PEXIT);',1)

    if k in {'interpreter_streamLibrary_FileNative_cpp','interpreter_streamLibrary_StreamNative_cpp'}:
        pre='typedef unsigned long dev_t; typedef unsigned long ino_t; typedef unsigned short ushort; typedef unsigned short mode_t; typedef long off_t; typedef long time_t;\n'
        if not t.startswith('typedef unsigned long dev_t;'): t=pre+t

    if k=='interpreter_execution_NativeActivation_cpp':
        defs='''enum { REXX_VALUE_ARGLIST=2, REXX_VALUE_NAME=3, REXX_VALUE_SCOPE=4, REXX_VALUE_CSELF=5, REXX_VALUE_OSELF=6, REXX_VALUE_SUPER=7, ARGUMENT_EXISTS=1, SPECIAL_ARGUMENT=2, REXX_OPTIONAL_ARGUMENT=0x8000 };\ninline uint16_t ARGUMENT_TYPE(uint16_t t) { return (uint16_t)(t & ~REXX_OPTIONAL_ARGUMENT); }\ninline int IS_OPTIONAL_ARGUMENT(uint16_t t) { return (t & REXX_OPTIONAL_ARGUMENT) != 0; }\n'''
        if 'REXX_VALUE_OSELF=6' not in t: t=defs+t

    if k=='interpreter_concurrency_ActivityManager_cpp':
        t=t.replace('T operator++(){return ++v;} T operator++(int){T x=v;++v;return x;}','T operator++(){return ++v;} T operator++(int){T x=v;++v;return x;} T operator--(){return --v;} T operator--(int){T x=v;--v;return x;}')
        # direct spelling from dev14 MVS facade
        t=t.replace('class SysActivity { public:', 'class SysActivity { public: static thread_id_t queryThreadID();',1)
        t=t.replace('int request(uint32_t) { return 1; }\n    int release() { return 1; }','int request(uint32_t) { return 1; }\n    int requestImmediate() { return 1; }\n    int release() { return 1; }')


    # dev15 round 4
    if k in {'interpreter_streamLibrary_FileNative_cpp','interpreter_streamLibrary_StreamNative_cpp'}:
        t=t.replace('extern int stat (const char*, stat*),\n           fstat (int, stat*);',
                    'extern int stat (const char*, struct stat *),\n           fstat (int, struct stat *);')

    if k=='interpreter_execution_NativeActivation_cpp':
        # Do not inject macro helper functions before the integer typedefs; make
        # the already-preprocessed use sites explicit old-C++ expressions.
        t=re.sub(r'^enum \{ REXX_VALUE_ARGLIST=2.*?IS_OPTIONAL_ARGUMENT\(uint16_t t\) \{ return \(t & REXX_OPTIONAL_ARGUMENT\) != 0; \}\n','',t,flags=re.M|re.S)
        t=re.sub(r'ARGUMENT_TYPE\(([^\)]+)\)', r'((\1) & ~0x8000)', t)
        t=re.sub(r'IS_OPTIONAL_ARGUMENT\(([^\)]+)\)', r'(((\1) & 0x8000) != 0)', t)
        vals={'REXX_VALUE_ARGLIST':'2','REXX_VALUE_NAME':'3','REXX_VALUE_SCOPE':'4','REXX_VALUE_CSELF':'5','REXX_VALUE_OSELF':'6','REXX_VALUE_SUPER':'7','ARGUMENT_EXISTS':'1','SPECIAL_ARGUMENT':'2',
              'INT_MAX':'2147483647','INT_MIN':'(-2147483647-1)','INT8_MAX':'127','INT8_MIN':'(-128)','INT16_MAX':'32767','INT16_MIN':'(-32768)','SSIZE_MAX':'2147483647','UINT8_MAX':'255','UINT16_MAX':'65535'}
        for s,v in vals.items(): t=re.sub(r'\b'+s+r'\b',v,t)
        if 'value_POINTERSTRING;' not in t:
            t=t.replace('POINTER value_POINTER;','POINTER value_POINTER;\n        POINTER value_POINTERSTRING;',1)

    if k=='interpreter_concurrency_ActivityManager_cpp':
        t=t.replace('int request() { return 1; }\n    void release() {}','int request() { return 1; }\n    int requestImmediate() { return 1; }\n    void release() {}',1)
    (root/p.name).write_text(t)
