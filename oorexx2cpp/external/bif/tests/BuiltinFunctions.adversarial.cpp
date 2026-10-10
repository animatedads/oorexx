/*
BUILTIN(FAKE_COMMENT)
{ const size_t FAKE_COMMENT_Min = 0; const size_t FAKE_COMMENT_Max = 0; }
*/
const char* misleading = "BUILTIN(FAKE_STRING)";
const char* arity = "const size_t REVERSE_Min = 99;";
// BUILTIN(FAKE_LINE)
BUILTIN(REVERSE)
{
    const size_t REVERSE_Min = 1;
    const size_t REVERSE_Max = 1;
    const size_t REVERSE_string = 1;
    /* const size_t REVERSE_Min = 999; */
    // const size_t REVERSE_Max = 44;
    fix_args(REVERSE);
    RexxString *string = required_string(REVERSE, string);
    return string->reverse();
}
