// Verified excerpts of ooRexx interpreter/expression/BuiltinFunctions.cpp
// Source commit blob SHA: 05ea58114e9e5b59a1cceebf8dd418b78058d342
// Only ARG and ADDRESS are extracted; do not claim a full upstream scan.
BUILTIN(ADDRESS)
{
    const size_t ADDRESS_Min = 0;
    const size_t ADDRESS_Max = 0;
    check_args(ADDRESS);
    return context->getAddress();
}

BUILTIN(ARG)
{
    const size_t ARG_Min = 0;
    const size_t ARG_Max = 2;
    const size_t ARG_n = 1;
    const size_t ARG_option = 2;
    fix_args(ARG);
    RexxInteger *n = optional_integer(ARG, n);
    RexxString *option = optional_string(ARG, option);
    RexxObject **arglist = context->getMethodArgumentList();
    size_t size = context->getMethodArgumentCount();
    if (n == OREF_NULL)
    {
        if (option != OREF_NULL)
        {
            reportException(Error_Incorrect_call_noarg, "ARG", IntegerOne);
        }
        return new_integer(size);
    }
    else if (option == OREF_NULL)
    {
        wholenumber_t position = n->getValue();
        positive_integer(position, ARG, IntegerOne);
        if (size < (size_t)position) return GlobalNames::NULLSTRING;
        RexxObject *result = arglist[position - 1];
        if (result == OREF_NULL) return GlobalNames::NULLSTRING;
        return result;
    }
    else
    {
        wholenumber_t position = n->getValue();
        positive_integer(position, ARG, IntegerOne);
        switch (Utilities::toUpper(option->getChar(0)))
        {
            case 'A':
                if (position == 1) return new_array(size, arglist);
                if ((size_t)position > size) return new_array();
                return new_array(size - (size_t)position + 1, &arglist[position - 1]);
            case 'E':
                if ((size_t)position > size) return TheFalseObject;
                return booleanObject(arglist[position - 1] != OREF_NULL);
            case 'O':
                if ((size_t)position > size) return TheTrueObject;
                return booleanObject(arglist[position - 1] == OREF_NULL);
            case 'N':
                if ((size_t)position > size) return GlobalNames::NULLSTRING;
                else
                {
                    RexxObject *result = arglist[position - 1];
                    if (result == OREF_NULL) return GlobalNames::NULLSTRING;
                    return result;
                }
            default:
                reportException(Error_Incorrect_call_list, "ARG", IntegerTwo, "AENO", option);
        }
    }
    return GlobalNames::NULLSTRING;
}
