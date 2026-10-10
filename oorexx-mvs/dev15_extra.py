from pathlib import Path
import re,sys
root=Path(sys.argv[1])
for p in root.glob('*.ii'):
    k=p.stem; t=p.read_text(errors='ignore')
    if k=='interpreter_api_InterpreterAPI_cpp':
        for s,v in [('RXCOMMAND','0'),('RXARI_NOT_FOUND','1'),('RXARI_OK','0'),('ORX_VER','5'),('ORX_REL','3'),('ORX_MOD','0'),('ORX_BLD','0')]:
            t=re.sub(r'\b'+s+r'\b',v,t)
        t=t.replace('OOREXX_COPY_YEAR','"2005-2026"')
        # old cfront rejects initialized automatic arrays; these are immutable text.
        t=re.sub(r'char\s+(header|build|mode|copy1|copy2|copy3|copy4|copy5)\[\]\s*=\s*([^;]+);',r'const char *\1 = \2;',t)
        t=t.replace('"\\nAddressing mode: 32"','"\\nAddressing mode: 24"')

    if k=='interpreter_api_InterpreterInstanceStubs_cpp':
        for s,v in [('DIRECT_COMMAND_ENVIRONMENT','1'),('REDIRECTING_COMMAND_ENVIRONMENT','2'),('INSTANCE_INTERFACE_VERSION','101')]:
            t=re.sub(r'\b'+s+r'\b',v,t)

    if k=='interpreter_api_InterpreterInstanceStubs_cpp':
        t=t.replace('struct RexxInstanceInterface { int reserved; };','struct RexxInstanceInterface;',1)
        marker='struct RexxThreadContext;'
        full='struct RexxInstanceInterface { wholenumber_t interfaceVersion; void (*Terminate)(RexxInstance *); logical_t (*AttachThread)(RexxInstance *, RexxThreadContext **); size_t (*InterpreterVersion)(RexxInstance *); size_t (*LanguageLevel)(RexxInstance *); void (*Halt)(RexxInstance *); void (*SetTrace)(RexxInstance *, logical_t); void (*AddCommandEnvironment)(RexxInstance *, const char *, REXXPFN, int); };'
        t=t.replace(marker,marker+'\n'+full,1)

    if k=='interpreter_classes_RexxQueueMethods_cpp':
        old='struct RexxMethodContext {\n    RexxThreadContext *threadContext;\n    void *functions;\n};'
        new='struct RexxMethodContext { RexxThreadContext *threadContext; void *functions; RexxObjectPtr GetObjectVariable(CSTRING); void RaiseException1(int, RexxObjectPtr); RexxObjectPtr GetSelf(); CSTRING ObjectToStringValue(RexxObjectPtr); RexxStringObject NewString(const char *, size_t); RexxStringObject NewStringFromAsciiz(const char *); RexxObjectPtr Nil(); RexxStringObject NullString(); void SetGuardOff(); CSTRING StringData(RexxStringObject); size_t StringLength(RexxStringObject); };'
        t=t.replace(old,new,1)
        t=t.replace('Rexx_Error_Execution_noinit','98901').replace('Rexx_Error_System_service_service','48001')
    (root/p.name).write_text(t)
