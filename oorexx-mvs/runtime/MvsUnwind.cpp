/*
 * ooRexx MVS 3.8J non-local activation unwind seam.
 *
 * cfront 3 has no C++ exception implementation.  ooRexx uses pointer-valued
 * exceptions as interpreter control flow, so the MVS port represents those
 * transfers explicitly using an SJLJ frame chain.
 *
 * setjmp() is executed in the catching function itself.  mvsUnwindRaise()
 * only selects a matching frame and longjmps to it; it never captures an
 * environment in a helper stack frame.
 *
 * The task-local frame slot is deliberately abstract.  The supplied single-
 * task implementation is sufficient for the initial MVS 3.8J bootstrap.  A
 * multi-task runtime must bind mvsUnwindGetTop/mvsUnwindSetTop to task-local
 * interpreter state before concurrency qualification.
 */
typedef int MvsJmpBuf[32];
void longjmp(int *, int);

struct MvsUnwindFrame
{
    MvsJmpBuf env;
    MvsUnwindFrame *previous;
    void *object;
    int type;
};

enum
{
    MVS_UNWIND_REXX_ACTIVATION = 1,
    MVS_UNWIND_NATIVE_ACTIVATION = 2
};

MvsUnwindFrame *mvsUnwindGetTop();
void mvsUnwindSetTop(MvsUnwindFrame *);
void mvsUnwindUncaught(int, void *);

void mvsUnwindPush(MvsUnwindFrame *frame, int type)
{
    frame->previous = mvsUnwindGetTop();
    frame->object = 0;
    frame->type = type;
    mvsUnwindSetTop(frame);
}

void mvsUnwindPop(MvsUnwindFrame *frame)
{
    if (mvsUnwindGetTop() == frame)
    {
        mvsUnwindSetTop(frame->previous);
    }
}

void mvsUnwindRaise(int type, void *object)
{
    MvsUnwindFrame *frame = mvsUnwindGetTop();
    while (frame != 0 && frame->type != type)
    {
        frame = frame->previous;
    }
    if (frame == 0)
    {
        mvsUnwindUncaught(type, object);
        return;
    }
    frame->object = object;
    mvsUnwindSetTop(frame);
    longjmp(frame->env, 1);
}
