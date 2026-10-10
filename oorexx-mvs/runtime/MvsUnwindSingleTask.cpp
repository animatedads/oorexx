/*
 * Single-task bootstrap binding for the MVS 3.8J unwind chain.
 * This binding MUST NOT be reused for concurrently executing tasks.
 */
struct MvsUnwindFrame;
static MvsUnwindFrame *mvsUnwindTop = 0;
MvsUnwindFrame *mvsUnwindGetTop() { return mvsUnwindTop; }
void mvsUnwindSetTop(MvsUnwindFrame *frame) { mvsUnwindTop = frame; }

/*
 * An unmatched ooRexx activation transfer is fatal, not a normal return.
 * In particular, never let mvsUnwindRaise() resume after no catch exists.
 * The C abort symbol is supplied by the selected cc370 runtime; the eventual
 * MVS failure/abend provider may replace this bootstrap implementation.
 */
extern "C" void abort(void);
void mvsUnwindUncaught(int, void *)
{
    abort();
    for (;;) { }  /* fail closed even if a broken abort provider returns */
}
