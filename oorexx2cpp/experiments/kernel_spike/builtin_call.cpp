#include "RexxCore.h"
#include "StringClass.hpp"
#include "IntegerClass.hpp"
#include "RexxActivation.hpp"
#include "Activity.hpp"
#include "ExpressionStack.hpp"
#include "BuiltinFunctions.hpp"
#include "ContextApi.hpp"
#include "oorexxapi.h"
#include <cstdio>
BUILTIN(SUBSTR); BUILTIN(LEFT); BUILTIN(POS); BUILTIN(X2D);
static void show(const char *label, RexxObject *r) {
    if (r == OREF_NULL) { printf("%s -> (null)\n", label); return; }
    printf("%s -> [%s]\n", label, r->stringValue()->getStringData());
}
int main() {
    RexxInstance *inst; RexxThreadContext *thr;
    if (!RexxCreateInterpreter(&inst, &thr, nullptr)) return 1;
    {
        ApiContext ctx(thr);
        RexxInternalObject *frame[64]; 
        { ExpressionStack st(frame, 64);   // substr('hello',2,,'*')
          st.push(new_string("hello")); st.push(new_integer(2)); st.push(OREF_NULL); st.push(new_string("*"));
          try { show("substr('hello',2,,'*')", builtin_function_SUBSTR(NULL, 4, &st)); } catch (...) { printf("%s -> Rexx error raised by the kernel\n", "substr('hello',2,,'*')"); } }
        { ExpressionStack st(frame, 64);   // left('abc',,'*')
          st.push(new_string("abc")); st.push(OREF_NULL); st.push(new_string("*"));
          try { show("left('abc',,'*')", builtin_function_LEFT(NULL, 3, &st)); } catch (...) { printf("%s -> Rexx error raised by the kernel\n", "left('abc',,'*')"); } }
        { ExpressionStack st(frame, 64);   // pos('b','abcb',,3)
          st.push(new_string("b")); st.push(new_string("abcb")); st.push(OREF_NULL); st.push(new_integer(3));
          try { show("pos('b','abcb',,3)", builtin_function_POS(NULL, 4, &st)); } catch (...) { printf("%s -> Rexx error raised by the kernel\n", "pos('b','abcb',,3)"); } }
        { ExpressionStack st(frame, 64);   // x2d('ff')
          st.push(new_string("ff"));
          try { show("x2d('ff')", builtin_function_X2D(NULL, 1, &st)); } catch (...) { printf("%s -> Rexx error raised by the kernel\n", "x2d('ff')"); } }
    }
    inst->Terminate();
}
