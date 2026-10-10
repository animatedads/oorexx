/* Narrow upstream ooRexx BuiltinFunctions.cpp excerpt (CPL-1.0)
   used for source-shape admission; no interpreter implementation is copied. */
BUILTIN(X2D)
{
    const size_t X2D_Min = 1;
    const size_t X2D_Max = 2;
    const size_t X2D_string =  1;
    const size_t X2D_n =       2;

    fix_args(X2D);

    RexxString *string = required_string(X2D, string);
    RexxInteger *n = optional_integer(X2D, n);

    return string->x2d(n);
}
