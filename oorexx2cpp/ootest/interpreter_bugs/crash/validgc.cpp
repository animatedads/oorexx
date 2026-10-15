// Bug 2 follow-up: after the failed send, the stale OPEN activation stays on the activity stack with argList pointing
// at C stack memory that has been unwound. A garbage collection in that window marks whatever is there now.
#include <oorexxapi.h>
#include <cstdio>
#include <cstring>

__attribute__((noinline)) static void clobberStack()
{
    volatile void *junk[4096];
    for (size_t i = 0; i < 4096; i++) junk[i] = (void *)(uintptr_t)(0x10 + 8 * i);   // non-null, unmapped addresses
}

RexxMethod2(RexxObjectPtr, valid_then_gc, CSTRING, name, RexxObjectPtr, extra)
{
    RexxThreadContext *t = context->threadContext;
    RexxObjectPtr queueClass = t->FindClass("REXXQUEUE");
    t->SendMessage1(queueClass, "OPEN", t->String(name)); (void)extra;   // control: a valid send
    printf("valid send, CheckCondition=%d; now collecting\n", (int)t->CheckCondition()); fflush(stdout);
    clobberStack();
    RexxRoutineObject gc = t->NewRoutine("gc", "call gc 'F'; return 0", 21);
    t->CallRoutine(gc, NULLOBJECT);
    printf("survived the collection\n"); fflush(stdout);
    return context->Nil();
}

RexxMethodEntry validgc_methods[] = { REXX_METHOD(valid_then_gc, valid_then_gc), REXX_LAST_METHOD() };
RexxPackageEntry validgc_package_entry = {
    STANDARD_PACKAGE_HEADER
    REXX_INTERPRETER_5_0_0, "VALIDGC", "1.0.0", NULL, NULL, NULL, validgc_methods
};
OOREXX_GET_PACKAGE(validgc);
