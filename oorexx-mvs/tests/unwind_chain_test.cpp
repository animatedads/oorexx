/* Host-level selection test: longjmp is intercepted to check the chosen frame.
 * This deliberately does NOT qualify target MVS setjmp buffer ABI or unwinding
 * of destructors in intermediate C++ frames.
 */
#include <cstdio>
#include <cstring>
#include "../runtime/MvsUnwind.cpp"
#include "../runtime/MvsUnwindSingleTask.cpp"
struct Jumped { };
static int jmpCalls = 0;
static int *jmpTarget = 0;
void longjmp(int *p, int value)
{
    if (value != 1) throw 10;
    ++jmpCalls;
    jmpTarget = p;
    throw Jumped();
}
#define CHECK(x) do { if (!(x)) { std::fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #x); return 1; } } while (0)
int main(int argc, char **argv)
{
    if (argc == 2 && std::strcmp(argv[1], "--uncaught") == 0)
    {
        mvsUnwindRaise(MVS_UNWIND_REXX_ACTIVATION, (void *)1);
        return 41; /* must not return */
    }
    MvsUnwindFrame root, nested, latest;
    mvsUnwindPush(&root, MVS_UNWIND_REXX_ACTIVATION);
    CHECK(mvsUnwindGetTop() == &root);
    mvsUnwindPush(&nested, MVS_UNWIND_NATIVE_ACTIVATION);
    mvsUnwindPush(&latest, MVS_UNWIND_REXX_ACTIVATION);
    try { mvsUnwindRaise(MVS_UNWIND_NATIVE_ACTIVATION, (void *)15); }
    catch (Jumped &) { }
    CHECK(jmpCalls == 1 && jmpTarget == nested.env);
    CHECK(mvsUnwindGetTop() == &nested && nested.object == (void *)15);
    mvsUnwindPop(&nested);
    CHECK(mvsUnwindGetTop() == &root);
    try { mvsUnwindRaise(MVS_UNWIND_REXX_ACTIVATION, (void *)17); }
    catch (Jumped &) { }
    CHECK(jmpCalls == 2 && jmpTarget == root.env && root.object == (void *)17);
    mvsUnwindPop(&root);
    CHECK(mvsUnwindGetTop() == 0);
    std::puts("PASS MVS unwind chain selection (host mock)");
    return 0;
}
