BUILTIN(FAKE)
{
    const size_t FAKE_Min = 0;
    const size_t FAKE_Max = argcount;
    fix_args(FAKE);
    return 42;
}
