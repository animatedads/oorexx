from pathlib import Path
import re, sys
root=Path(sys.argv[1])
api_shapes=Path(__file__).with_name('api-interface-shapes.inc').read_text()
api_targets={'interpreter_api_CallContextStubs_cpp','interpreter_api_MethodContextStubs_cpp','interpreter_api_ThreadContextStubs_cpp'}
placeholders='''struct RexxThreadInterface { int reserved; };\nstruct MethodContextInterface { int reserved; };\nstruct CallContextInterface { int reserved; };\nstruct ExitContextInterface { int reserved; };\nstruct IORedirectorInterface { int reserved; };'''
marker='''struct RexxLibraryPackage {\n    const char *registeredName;\n    RexxPackageEntry *table;\n};'''
for p in root.glob('*.ii'):
    k=p.stem; t=p.read_text(errors='ignore')
    if k in api_targets:
        if placeholders not in t: raise SystemExit('api placeholders missing '+k)
        t=t.replace(placeholders,'struct RexxThreadInterface;\nstruct MethodContextInterface;\nstruct CallContextInterface;\nstruct ExitContextInterface;\nstruct IORedirectorInterface;',1)
        if marker not in t: raise SystemExit('api marker missing '+k)
        t=t.replace(marker,marker+'\n'+api_shapes,1)
        for s,v in [('THREAD_INTERFACE_VERSION','103'),('METHOD_INTERFACE_VERSION','102'),('CALL_INTERFACE_VERSION','101'),('EXIT_INTERFACE_VERSION','101'),('REDIRECT_INTERFACE_VERSION','100'),('NULLOBJECT','0')]:
            t=re.sub(r'\b'+s+r'\b',v,t)
    if k=='interpreter_classes_NumberStringMath2_cpp':
        t=t.replace('abs(calcExp)', '(calcExp < 0 ? -calcExp : calcExp)')
        x='left->numberExponent + left->digitsCount - 1'
        t=t.replace('abs('+x+')', '(('+x+') < 0 ? -('+x+') : ('+x+'))')
        t=t.replace('abs(powerValue)', '(powerValue < 0 ? -powerValue : powerValue)')
        # Both labels are only used to escape two nested division loops.
        old='''    wholenumber_t resultDigits = 0;\n    int thisDigit = 0;\n    for (; ; )\n'''
        new='''    wholenumber_t resultDigits = 0;\n    int thisDigit = 0;\n    int powerDivideDone = 0;\n    for (; ; )\n'''
        t=t.replace(old,new,1)
        t=t.replace('''                    resultDigits++;\n                    goto PowerDivideDone;\n''','''                    resultDigits++;\n                    powerDivideDone = 1;\n                    break;\n''',1)
        t=t.replace('''        }\n        if (resultDigits != 0 || thisDigit != 0)\n''','''        }\n        if (powerDivideDone)\n        {\n            break;\n        }\n        if (resultDigits != 0 || thisDigit != 0)\n''',1)
        t=t.replace('''    PowerDivideDone:\n    ;\n    if ((divOP != OT_DIVIDE)''','''    if ((divOP != OT_DIVIDE)''',1)
        idx=t.find('char *NumberString::dividePower(')
        if idx >= 0:
            head=t[:idx]; s=t[idx:]
            s=s.replace(old,new,1)
            s=s.replace('''                    resultDigits++;\n                    goto PowerDivideDone;\n''','''                    resultDigits++;\n                    powerDivideDone = 1;\n                    break;\n''',1)
            s=s.replace('''        }\n        if (resultDigits > 0 || thisDigit != 0)\n''','''        }\n        if (powerDivideDone)\n        {\n            break;\n        }\n        if (resultDigits > 0 || thisDigit != 0)\n''',1)
            s=s.replace('''    PowerDivideDone:\n    ;\n    accum->digitsCount''','''    accum->digitsCount''',1)
            t=head+s
    if k=='interpreter_classes_RexxQueueMethods_cpp':
        t=re.sub(r'\bNULLOBJECT\b','0',t)
        t=re.sub(r'RexxMethod0\s*\(\s*([^,]+)\s*,\s*([A-Za-z_]\w*)\s*\)',r'\1 \2(RexxMethodContext *context)',t)
        t=re.sub(r'RexxMethod1\s*\(\s*([^,]+)\s*,\s*([A-Za-z_]\w*)\s*,\s*([^,]+)\s*,\s*([A-Za-z_]\w*)\s*\)',r'\1 \2(RexxMethodContext *context, \3 \4)',t,flags=re.S)
        t=t.replace('OPTIONAL_RexxStringObject','RexxStringObject').replace('OPTIONAL_CSTRING','CSTRING')
        t=t.replace('MAKERXSTRING(rx_string, context->StringData(queue_line), context->StringLength(queue_line));','rx_string.strptr = context->StringData(queue_line); rx_string.strlength = context->StringLength(queue_line);')
        constants={'RXAPI_NORXAPI':'1004','RXAPI_MEMFAIL':'1002','RXQUEUE_FIFO':'0','RXQUEUE_LIFO':'1','RXQUEUE_NOWAIT':'0','RXQUEUE_WAIT':'1','RXQUEUE_BADQNAME':'5','RXQUEUE_PRIORITY':'6','RXQUEUE_BADWAITFLAG':'7','RXQUEUE_EMPTY':'8','RXQUEUE_NOTREG':'9','RXQUEUE_ACCESS':'10','MAX_QUEUE_NAME_LENGTH':'250'}
        for s,v in constants.items(): t=re.sub(r'\b'+s+r'\b',v,t)
        insert='''\nRexxReturnCode RexxCreateQueue(char *, size_t, const char *, size_t *);\nRexxReturnCode RexxOpenQueue(const char *, size_t *);\nRexxReturnCode RexxQueueExists(const char *);\nRexxReturnCode RexxDeleteQueue(const char *);\nRexxReturnCode RexxQueryQueue(const char *, size_t *);\nRexxReturnCode RexxAddQueue(const char *, CONSTRXSTRING *, size_t);\nRexxReturnCode RexxPullFromQueue(const char *, RXSTRING *, void *, size_t);\nRexxReturnCode RexxClearQueue(const char *);\nvoid RexxFreeMemory(void *);\n'''
        t=t.replace('int getQueueName(RexxMethodContext *context, CSTRING &name)',insert+'\nint getQueueName(RexxMethodContext *context, CSTRING &name)',1)
    if k=='interpreter_memory_GlobalNames_cpp':
        t=t.replace('GlobalNames::struct _iobuf','GlobalNames::FILE')
        t=t.replace('SYSINITIALADDRESS','rx_host_default_address_name()')
        t='extern "C" const char *rx_host_default_address_name();\n'+t
    p.write_text(t)
