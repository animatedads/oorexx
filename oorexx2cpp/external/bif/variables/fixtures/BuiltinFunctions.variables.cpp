// Source-derived structural excerpt, source blob SHA
// ooRexx/ooRexx interpreter/expression/BuiltinFunctions.cpp
// 05ea58114e9e5b59a1cceebf8dd418b78058d342
// This is NOT a full upstream source archive.
BUILTIN(SYMBOL)
{
    const size_t SYMBOL_Min = 1;
    const size_t SYMBOL_Max = 1;
    const size_t SYMBOL_name = 1;
    fix_args(SYMBOL);
    RexxString *name = required_string(SYMBOL, name);
    RexxVariableBase *variable = VariableDictionary::getVariableRetriever(name);
    if (variable == OREF_NULL) return GlobalNames::BAD;
    else if (isString(variable)) return GlobalNames::LIT;
    else if (!variable->exists(context)) return GlobalNames::LIT;
    else return GlobalNames::VAR;
}
BUILTIN(VAR)
{
    const size_t VAR_Min = 1;
    const size_t VAR_Max = 1;
    const size_t VAR_name = 1;
    fix_args(VAR);
    RexxString *variable = required_string(VAR, name);
    RexxVariableBase *retriever = VariableDictionary::getVariableRetriever(variable);
    if (retriever == OREF_NULL) return TheFalseObject;
    else if (isString(retriever)) return TheFalseObject;
    else return booleanObject(retriever->exists(context));
}
BUILTIN(VALUE)
{
    const size_t VALUE_Min = 1;
    const size_t VALUE_Max = 3;
    const size_t VALUE_name = 1;
    const size_t VALUE_newValue = 2;
    const size_t VALUE_selector = 3;
    fix_args(VALUE);
    RexxString *variable = required_string(VALUE, name);
    RexxObject *newvalue = optional_argument(VALUE, newValue);
    RexxString *selector = optional_string(VALUE, selector);
    StringSymbolType variableType = variable->isSymbol();
    bool assignable = variableType == STRING_NAME || variableType == STRING_STEM || variableType == STRING_COMPOUND_NAME;
    if (selector == OREF_NULL)
    {
        Protected<RexxVariableBase> retriever = VariableDictionary::getVariableRetriever(variable);
        if (retriever == OREF_NULL || (newvalue != OREF_NULL && !assignable))
            reportException(Error_Incorrect_call_symbol, "VALUE", IntegerOne, variable);
        result = retriever->getValue(context);
        if (newvalue != OREF_NULL) retriever->assign(context, newvalue);
        return result;
    }
    else if (selector->getLength() == 0)
    {
        result = (RexxObject *)TheEnvironment->entry(variable);
        if (result == OREF_NULL) result = variable->upper()->concatToCstring(".");
        if (newvalue != OREF_NULL) TheEnvironment->setEntry(variable, newvalue);
        return result;
    }
    else
    {
        if (selector->strCaselessCompare("ENVIRONMENT"))
        {
            SystemInterpreter::getEnvironmentVariable(variable->getStringData(), buffer);
            if (newvalue != OREF_NULL) SystemInterpreter::setEnvironmentVariable(variable->getStringData(), NULL);
            return result;
        }
        if (SystemInterpreter::valueFunction(variable, newvalue, selector, result)) return result;
        if (!context->getActivity()->callValueExit(context, selector, variable, newvalue, result)) return result;
        reportException(Error_Incorrect_call_selector, selector);
    }
}
