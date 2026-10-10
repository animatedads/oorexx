// Structural excerpt of upstream interpreter/expression/BuiltinFunctions.cpp
// Upstream blob SHA: 05ea58114e9e5b59a1cceebf8dd418b78058d342
// NOT a complete upstream file. Live source checkout accepted by bif2control.rex.
BUILTIN(SOURCELINE)
{
    const size_t SOURCELINE_Min = 0;
    const size_t SOURCELINE_Max = 1;
    const size_t SOURCELINE_n = 1;
    fix_args(SOURCELINE);
    PackageClass *package = context->getEffectivePackageObject();
    size_t size = package->sourceSize();
    if (argcount == 1) {
        size_t line_number = required_integer(SOURCELINE, n)->getValue();
        positive_integer((ssize_t)line_number, SOURCELINE, IntegerOne);
        if (line_number > size) reportException(Error_Incorrect_call_sourceline,line_number,size);
        return package->getLine(line_number);
    }
    return new_integer(size);
}
BUILTIN(TRACE)
{
    const size_t TRACE_Min = 0;
    const size_t TRACE_Max = 1;
    const size_t TRACE_setting = 1;
    fix_args(TRACE);
    RexxString *setting = optional_string(TRACE, setting);
    RexxString *result = context->traceSetting();
    if (setting != OREF_NULL) context->setTrace(setting);
    return result;
}
BUILTIN(CONDITION)
{
    const size_t CONDITION_Min = 0;
    const size_t CONDITION_Max = 1;
    const size_t CONDITION_option = 1;
    fix_args(CONDITION);
    RexxString *option = optional_string(CONDITION, option);
    DirectoryClass *conditionobj = context->getConditionObj();
    switch (option == OREF_NULL ? 'I' : option->getChar(0)) {
       case 'O': if (conditionobj != OREF_NULL) return (RexxObject*)conditionobj->copy(); break;
       case 'S': if (conditionobj != OREF_NULL) return context->trapState((RexxString *)conditionobj->get(GlobalNames::CONDITION)); break;
       case 'R': context->setConditionObj(OREF_NULL); return GlobalNames::NULLSTRING;
       default: return GlobalNames::NULLSTRING;
    }
    return GlobalNames::NULLSTRING;
}
