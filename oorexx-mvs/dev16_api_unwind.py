from pathlib import Path
import sys
root=Path(sys.argv[1])
EH='''\ntypedef int MvsJmpBuf[32];\nextern "C" int setjmp(MvsJmpBuf);\nextern "C" void longjmp(MvsJmpBuf, int);\nstruct MvsUnwindFrame { MvsJmpBuf env; MvsUnwindFrame *previous; void *object; int type; };\nenum { MVS_UNWIND_REXX_ACTIVATION = 1, MVS_UNWIND_NATIVE_ACTIVATION = 2 };\nvoid mvsUnwindPush(MvsUnwindFrame *, int);\nvoid mvsUnwindPop(MvsUnwindFrame *);\nvoid mvsUnwindRaise(int, void *);\nclass MvsNativeUnwindGuard { public: MvsNativeUnwindGuard() { mvsUnwindPush(&frame, MVS_UNWIND_NATIVE_ACTIVATION); } ~MvsNativeUnwindGuard() { mvsUnwindPop(&frame); } MvsUnwindFrame frame; };\n'''

def match_brace(t, open_pos):
    d=0; i=open_pos
    while i < len(t):
        c=t[i]
        if c=='{': d+=1
        elif c=='}':
            d-=1
            if d==0: return i
        i+=1
    raise RuntimeError('unmatched brace')

def convert(t):
    pos=0; n=0
    while True:
        i=t.find('try',pos)
        if i<0: break
        # require standalone token and brace after whitespace
        if (i>0 and (t[i-1].isalnum() or t[i-1]=='_')) or (i+3<len(t) and (t[i+3].isalnum() or t[i+3]=='_')):
            pos=i+3; continue
        j=i+3
        while j<len(t) and t[j].isspace(): j+=1
        if j>=len(t) or t[j]!='{': pos=i+3; continue
        end_try=match_brace(t,j)
        k=end_try+1
        while k<len(t) and t[k].isspace(): k+=1
        sig='catch (NativeActivation *)'
        if not t.startswith(sig,k): pos=end_try+1; continue
        c=k+len(sig)
        while c<len(t) and t[c].isspace(): c+=1
        if c>=len(t) or t[c]!='{': raise RuntimeError('catch brace missing')
        end_catch=match_brace(t,c)
        try_body=t[j+1:end_try]
        catch_body=t[c+1:end_catch]
        n+=1; g='mvsApiGuard%d'%n
        repl=('MvsNativeUnwindGuard '+g+';\n'
              '    if (setjmp('+g+'.frame.env) == 0)\n    {'+try_body+'\n    }\n'
              '    else\n    {\n        mvsUnwindPop(&'+g+'.frame);'+catch_body+'\n    }')
        t=t[:i]+repl+t[end_catch+1:]
        pos=i+len(repl)
    return t,n

for p in root.glob('interpreter_api_*ContextStubs_cpp.ii'):
    t=p.read_text(errors='ignore')
    t,n=convert(t)
    if n:
        t=EH+t
        p.write_text(t)
        print(p.name,n)
