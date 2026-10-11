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
    /* A null frame or duplicate entry would corrupt the SJLJ chain.  These
     * are programming faults, not ooRexx language exceptions.  Fail closed. */
    if (frame == 0 || (type != MVS_UNWIND_REXX_ACTIVATION &&
                       type != MVS_UNWIND_NATIVE_ACTIVATION))
    {
        mvsUnwindUncaught(0, frame);
        for (;;) { }
    }
    MvsUnwindFrame *entry = mvsUnwindGetTop();
    while (entry != 0)
    {
        if (entry == frame)
        {
            mvsUnwindUncaught(0, frame);
            for (;;) { }
        }
        entry = entry->previous;
    }
    frame->previous = mvsUnwindGetTop();
    frame->object = 0;
    frame->type = type;
    mvsUnwindSetTop(frame);
}

void mvsUnwindPop(MvsUnwindFrame *frame)
{
    /* Silently ignoring an out-of-order or repeated pop leaves the active
     * stack pointing at expired frames.  It must never resume execution. */
    if (frame == 0 || mvsUnwindGetTop() != frame)
    {
        mvsUnwindUncaught(0, frame);
        for (;;) { }
    }
    mvsUnwindSetTop(frame->previous);
    frame->previous = 0;
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
        for (;;) { }   /* even if an invalid failure handler returns */
    }
    frame->object = object;
    mvsUnwindSetTop(frame);
    longjmp(frame->env, 1);
}
