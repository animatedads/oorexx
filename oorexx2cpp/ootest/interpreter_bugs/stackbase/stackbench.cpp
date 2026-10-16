// stackbench: CallRoutine from native code, N times (each call enters Activity::run, which asks for the stack base)
#include <oorexxapi.h>

RexxRoutine2(int, callRoutineLoop, RexxObjectPtr, routine, int, count)
{
    RexxArrayObject args = context->NewArray(0);
    for (int i = 0; i < count; i++)
    {
        context->CallRoutine((RexxRoutineObject)routine, args);
        if (context->CheckCondition()) return -1;
    }
    return count;
}

RexxRoutineEntry stackbench_routines[] =
{
    REXX_TYPED_ROUTINE(callRoutineLoop, callRoutineLoop),
    REXX_LAST_ROUTINE()
};

RexxPackageEntry stackbench_package_entry =
{
    STANDARD_PACKAGE_HEADER
    REXX_INTERPRETER_5_0_0,
    "stackbench", "1.0.0", NULL, NULL,
    stackbench_routines, NULL
};

OOREXX_GET_PACKAGE(stackbench);
