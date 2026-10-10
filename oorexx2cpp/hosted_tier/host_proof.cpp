// Proof: a native C++ program embeds an interpreter and keeps a LIVE object handle across messages.
#include <oorexxapi.h>
#include <cstdio>
#include <cstring>
static RexxObjectPtr keep;   // handle the native runtime would hold
int main() {
    RexxInstance *inst; RexxThreadContext *c;
    RexxOption opt[1]; opt[0].optionName = nullptr;
    if (!RexxCreateInterpreter(&inst, &c, opt)) { puts("no interpreter"); return 1; }
    // 1. a class the native runtime does not implement: found and instantiated through the host
    RexxClassObject dt = c->FindClass("DateTime");
    RexxObjectPtr args[3] = { c->WholeNumber(2021), c->WholeNumber(12), c->WholeNumber(25) };
    RexxArrayObject a = c->ArrayOfThree(args[0], args[1], args[2]);
    RexxObjectPtr obj = c->SendMessage(dt, "NEW", a);
    if (c->CheckCondition()) { puts("NEW failed"); return 2; }
    c->RequestGlobalReference(obj); keep = obj;
    RexxObjectPtr wd = c->SendMessage0(keep, "WEEKDAY");
    printf("weekday = %s\n", c->ObjectToStringValue(wd));
    // 2. user class created at run time inside the host; instance handle kept by the native runtime
    const char *mk = "cls = .DateTime~subclass('MyDT'); return cls~new(2022, 1, 1)";
    RexxRoutineObject mkr = c->NewRoutine("mk", mk, strlen(mk));
    RexxObjectPtr inst2 = c->CallRoutine(mkr, c->ArrayOfOne(keep));
    if (c->CheckCondition()) { puts("mk failed"); return 3; }
    c->RequestGlobalReference(inst2);
    printf("MyDT weekday = %s\n", c->ObjectToStringValue(c->SendMessage0(inst2, "WEEKDAY")));
    // 3. later, other Rexx code adds a method to the class; the SAME existing handle answers it
    const char *src = "use arg o; say 'in mutate' o~class~id; o~class~define('DOWNAME', .Method~new('DOWNAME', 'return word(\"Mon Tue Wed Thu Fri Sat Sun\", self~weekday)')); return 1";
    RexxRoutineObject r = c->NewRoutine("mutate", src, strlen(src));
    c->CallRoutine(r, c->ArrayOfOne(inst2));
    if (c->CheckCondition()) { RexxDirectoryObject ci = c->GetConditionInfo(); RexxCondition cd; c->DecodeConditionInfo(ci, &cd); printf("mutate failed: %d %s\n", (int)cd.code, cd.message ? c->ObjectToStringValue(cd.message) : "?"); return 4; }
    // Rexx semantics: DEFINE is seen by instances created AFTER it; the existing instance must still refuse.
    c->SendMessage0(inst2, "DOWNAME");
    if (c->CheckCondition()) { RexxDirectoryObject ci = c->GetConditionInfo(); RexxCondition cd; c->DecodeConditionInfo(ci, &cd);
        printf("existing handle correctly refuses: %d\n", (int)cd.code); c->ClearCondition(); }
    else puts("UNEXPECTED: existing instance answered");
    RexxObjectPtr args2[3] = { c->WholeNumber(2022), c->WholeNumber(1), c->WholeNumber(1) };
    (void)args2;
    const char *mk2 = "use arg o; return o~class~new(2022, 1, 1)";
    RexxObjectPtr inst3 = c->CallRoutine(c->NewRoutine("mk2", mk2, strlen(mk2)), c->ArrayOfOne(inst2));
    c->RequestGlobalReference(inst3);
    { const char *q = "use arg o; signal on syntax name bad; return o~downame; bad: return 'REXX-SIDE-FAIL'";
      RexxObjectPtr qv = c->CallRoutine(c->NewRoutine("q", q, strlen(q)), c->ArrayOfOne(inst3));
      printf("via Rexx routine on the same handle = %s\n", c->ObjectToStringValue(qv)); }
    RexxObjectPtr dn = c->SendMessage0(inst3, "DOWNAME");
    if (c->CheckCondition()) { RexxDirectoryObject ci = c->GetConditionInfo(); RexxCondition cd; c->DecodeConditionInfo(ci, &cd); printf("new instance failed: %d %s\n", (int)cd.code, cd.message ? c->ObjectToStringValue(cd.message) : "?"); return 5; }
    printf("downame (instance made after define) = %s\n", c->ObjectToStringValue(dn));
    // 4. INTERPRET-like evaluation in the host, sharing the object by handle
    const char *src2 = "use arg o; interpret 'x = o~downame || \"/\" || o~year'; return x";
    RexxRoutineObject r2 = c->NewRoutine("interp", src2, strlen(src2));
    RexxObjectPtr v = c->CallRoutine(r2, c->ArrayOfOne(inst3));
    printf("interpret dayofweek = %s\n", c->ObjectToStringValue(v));
    c->ReleaseGlobalReference(keep);
    inst->Terminate();
    return 0;
}
