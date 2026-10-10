/* Upstream ooRexx BuiltinFunctions.cpp, functions DIGITS/FUZZ/FORM,
   blob 05ea58114e9e5b59a1cceebf8dd418b78058d342.
   Selected source bodies reproduced under upstream CPL v1.0 notice. */
BUILTIN(DIGITS)
{
    const size_t DIGITS_Min = 0;
    const size_t DIGITS_Max = 0;

    check_args(DIGITS);

    return new_integer(context->digits());
}

BUILTIN(FUZZ)
{
    const size_t FUZZ_Min = 0;
    const size_t FUZZ_Max = 0;

    check_args(FUZZ);

    return new_integer(context->fuzz());
}

BUILTIN(FORM)
{
    const size_t FORM_Min = 0;
    const size_t FORM_Max = 0;

    check_args(FORM);

    return context->form() == Numerics::FORM_SCIENTIFIC ? GlobalNames::SCIENTIFIC : GlobalNames::ENGINEERING;
}

/* Upstream FORMAT (same source blob), exact source-level front door. */
BUILTIN(FORMAT)
{
    const size_t FORMAT_Min = 1;
    const size_t FORMAT_Max = 5;
    const size_t FORMAT_number = 1;
    const size_t FORMAT_before = 2;
    const size_t FORMAT_after =  3;
    const size_t FORMAT_expp =   4;
    const size_t FORMAT_expt =   5;

    fix_args(FORMAT);

    RexxString *number = required_string(FORMAT, number);
    RexxInteger *before = optional_integer(FORMAT, before);
    RexxInteger *after = optional_integer(FORMAT, after);
    RexxInteger *expp = optional_integer(FORMAT, expp);
    RexxInteger *expt = optional_integer(FORMAT, expt);

    return number->format(before, after, expp, expt);
}
