/* This narrow fixture is derived from the upstream ooRexx BuiltinFunctions.cpp
   SIGN BIF. Original C++ remains owned by the Rexx Language Association.
   See upstream CPL notice and source pin in the BIF add-on. */
BUILTIN(SIGN)
{
    const size_t SIGN_Min = 1;
    const size_t SIGN_Max = 1;
    const size_t SIGN_n = 1;
    fix_args(SIGN);
    RexxObject *argument = get_arg(SIGN, n);
    if (isInteger(argument)) return((RexxInteger *)argument)->sign();
    else if (isNumberString(argument)) return((NumberString *)argument)->Sign();
    RexxString *n = required_string(SIGN, n);
    return n->sign();
}
