/* Exercise native catch guard release with a real strict frame stack.
 * No target-jmp_buf assertion is made by this host-only test. */
#include <cstdio>
#include "../runtime/MvsUnwind.cpp"
#include "../runtime/MvsUnwindSingleTask.cpp"
void longjmp(int *, int) { }
class MvsNativeUnwindGuard
{
public:
    MvsNativeUnwindGuard() : armed(1)
    {
        mvsUnwindPush(&frame, MVS_UNWIND_NATIVE_ACTIVATION);
    }
    void release()
    {
        if (armed)
        {
            armed = 0;
            mvsUnwindPop(&frame);
        }
    }
    ~MvsNativeUnwindGuard() { release(); }
    MvsUnwindFrame frame;
private:
    int armed;
};
int main()
{
    {
        MvsNativeUnwindGuard guard;
        if (mvsUnwindGetTop() != &guard.frame) return 1;
    }
    if (mvsUnwindGetTop() != 0) return 2;
    {
        MvsNativeUnwindGuard guard;
        guard.release();
        if (mvsUnwindGetTop() != 0) return 3;
        guard.release();  /* explicit repeat is safe */
    }
    if (mvsUnwindGetTop() != 0) return 4; /* destructor did not pop twice */
    std::puts("PASS MVS API guard normal release and catch release are single-pop");
    return 0;
}
