/* Minimal, attributed upstream BuiltinFunctions.cpp wrapper for source rule gating. */
BUILTIN(TRUNC)
{
    const size_t TRUNC_Min = 1;
    const size_t TRUNC_Max = 2;
    const size_t TRUNC_number = 1;
    const size_t TRUNC_n = 2;
    fix_args(TRUNC);
    RexxString *number = required_string(TRUNC, number);
    RexxInteger *n = optional_integer(TRUNC, n);
    return number->trunc(n);
}
