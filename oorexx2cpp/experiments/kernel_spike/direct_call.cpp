#include "RexxCore.h"
#include "StringClass.hpp"
#include "IntegerClass.hpp"
#include "ContextApi.hpp"
#include "oorexxapi.h"
#include <cstdio>
int main() {
    RexxInstance *inst; RexxThreadContext *thr;
    if (!RexxCreateInterpreter(&inst, &thr, nullptr)) { puts("no interpreter"); return 1; }
    {
        ApiContext ctx(thr);
        RexxString *s = new_string("hello");
        RexxString *pad = new_string("*");
        RexxString *r = s->substr(new_integer(2), OREF_NULL, pad);   // substr('hello',2,,'*')
        printf("[%s]\n", r->getStringData());
        RexxString *r2 = s->substr(new_integer(2), new_integer(6), pad);
        printf("[%s]\n", r2->getStringData());
    }
    inst->Terminate();
    return 0;
}
