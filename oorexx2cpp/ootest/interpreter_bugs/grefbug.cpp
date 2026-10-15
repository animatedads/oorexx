// Reproduction for two ooRexx native API problems (ooRexx 5.3.0 r13196).
//   KEEPRELEASE(obj): RequestGlobalReference(obj) then ReleaseGlobalReference(obj) -- should leave obj collectable.
//   SENDOPEN(name, extra): SendMessage(.RexxQueue, "OPEN", [name, extra]) -- OPEN takes one argument, so 88.922 is raised;
//                          returns "condition=<CheckCondition()> result=<NULL|object>".
#include <oorexxapi.h>
#include <cstdio>

RexxMethod1(RexxObjectPtr, keep_release, RexxObjectPtr, obj)
{
    RexxThreadContext *t = context->threadContext;
    t->RequestGlobalReference(obj);
    t->ReleaseGlobalReference(obj);
    return context->Nil();
}

RexxMethod2(RexxObjectPtr, send_open, CSTRING, name, RexxObjectPtr, extra)
{
    RexxThreadContext *t = context->threadContext;
    RexxObjectPtr queueClass = t->FindClass("REXXQUEUE");
    RexxObjectPtr r = t->SendMessage2(queueClass, "OPEN", t->String(name), extra);
    char buf[100];
    snprintf(buf, sizeof buf, "condition=%d result=%s", (int)t->CheckCondition(), r == NULLOBJECT ? "NULL" : "object");
    printf("inside the native method: %s\n", buf);   // what native code sees
    fflush(stdout);
    return t->String(buf);
}

RexxMethodEntry grefbug_methods[] = {
    REXX_METHOD(keep_release, keep_release),
    REXX_METHOD(send_open, send_open),
    REXX_LAST_METHOD()
};
RexxPackageEntry grefbug_package_entry = {
    STANDARD_PACKAGE_HEADER
    REXX_INTERPRETER_5_0_0, "GREFBUG", "1.0.0", NULL, NULL, NULL, grefbug_methods
};
OOREXX_GET_PACKAGE(grefbug);
