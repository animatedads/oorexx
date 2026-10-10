// GENERATED from oorexxapi.h RexxThreadInterface: every slot defaults to a named fail-closed trap.
[[noreturn]] static void trap_DetachThread() { trapped("DetachThread"); }
[[noreturn]] static void trap_HaltThread() { trapped("HaltThread"); }
[[noreturn]] static void trap_SetThreadTrace() { trapped("SetThreadTrace"); }
[[noreturn]] static void trap_RequestGlobalReference() { trapped("RequestGlobalReference"); }
[[noreturn]] static void trap_ReleaseGlobalReference() { trapped("ReleaseGlobalReference"); }
[[noreturn]] static void trap_ReleaseLocalReference() { trapped("ReleaseLocalReference"); }
[[noreturn]] static void trap_SendMessage() { trapped("SendMessage"); }
[[noreturn]] static void trap_SendMessage0() { trapped("SendMessage0"); }
[[noreturn]] static void trap_SendMessage1() { trapped("SendMessage1"); }
[[noreturn]] static void trap_SendMessage2() { trapped("SendMessage2"); }
[[noreturn]] static void trap_GetLocalEnvironment() { trapped("GetLocalEnvironment"); }
[[noreturn]] static void trap_GetGlobalEnvironment() { trapped("GetGlobalEnvironment"); }
[[noreturn]] static void trap_IsInstanceOf() { trapped("IsInstanceOf"); }
[[noreturn]] static void trap_IsOfType() { trapped("IsOfType"); }
[[noreturn]] static void trap_HasMethod() { trapped("HasMethod"); }
[[noreturn]] static void trap_LoadPackage() { trapped("LoadPackage"); }
[[noreturn]] static void trap_LoadPackageFromData() { trapped("LoadPackageFromData"); }
[[noreturn]] static void trap_LoadLibrary() { trapped("LoadLibrary"); }
[[noreturn]] static void trap_RegisterLibrary() { trapped("RegisterLibrary"); }
[[noreturn]] static void trap_FindClass() { trapped("FindClass"); }
[[noreturn]] static void trap_FindPackageClass() { trapped("FindPackageClass"); }
[[noreturn]] static void trap_GetPackageRoutines() { trapped("GetPackageRoutines"); }
[[noreturn]] static void trap_GetPackagePublicRoutines() { trapped("GetPackagePublicRoutines"); }
[[noreturn]] static void trap_GetPackageClasses() { trapped("GetPackageClasses"); }
[[noreturn]] static void trap_GetPackagePublicClasses() { trapped("GetPackagePublicClasses"); }
[[noreturn]] static void trap_GetPackageMethods() { trapped("GetPackageMethods"); }
[[noreturn]] static void trap_CallRoutine() { trapped("CallRoutine"); }
[[noreturn]] static void trap_CallProgram() { trapped("CallProgram"); }
[[noreturn]] static void trap_NewMethod() { trapped("NewMethod"); }
[[noreturn]] static void trap_NewRoutine() { trapped("NewRoutine"); }
[[noreturn]] static void trap_IsRoutine() { trapped("IsRoutine"); }
[[noreturn]] static void trap_IsMethod() { trapped("IsMethod"); }
[[noreturn]] static void trap_GetRoutinePackage() { trapped("GetRoutinePackage"); }
[[noreturn]] static void trap_GetMethodPackage() { trapped("GetMethodPackage"); }
[[noreturn]] static void trap_ObjectToCSelf() { trapped("ObjectToCSelf"); }
[[noreturn]] static void trap_WholeNumberToObject() { trapped("WholeNumberToObject"); }
[[noreturn]] static void trap_UintptrToObject() { trapped("UintptrToObject"); }
[[noreturn]] static void trap_IntptrToObject() { trapped("IntptrToObject"); }
[[noreturn]] static void trap_ValueToObject() { trapped("ValueToObject"); }
[[noreturn]] static void trap_ValuesToObject() { trapped("ValuesToObject"); }
[[noreturn]] static void trap_ObjectToValue() { trapped("ObjectToValue"); }
[[noreturn]] static void trap_StringSizeToObject() { trapped("StringSizeToObject"); }
[[noreturn]] static void trap_ObjectToWholeNumber() { trapped("ObjectToWholeNumber"); }
[[noreturn]] static void trap_ObjectToStringSize() { trapped("ObjectToStringSize"); }
[[noreturn]] static void trap_Int64ToObject() { trapped("Int64ToObject"); }
[[noreturn]] static void trap_UnsignedInt64ToObject() { trapped("UnsignedInt64ToObject"); }
[[noreturn]] static void trap_ObjectToInt64() { trapped("ObjectToInt64"); }
[[noreturn]] static void trap_ObjectToUnsignedInt64() { trapped("ObjectToUnsignedInt64"); }
[[noreturn]] static void trap_Int32ToObject() { trapped("Int32ToObject"); }
[[noreturn]] static void trap_UnsignedInt32ToObject() { trapped("UnsignedInt32ToObject"); }
[[noreturn]] static void trap_ObjectToInt32() { trapped("ObjectToInt32"); }
[[noreturn]] static void trap_ObjectToUnsignedInt32() { trapped("ObjectToUnsignedInt32"); }
[[noreturn]] static void trap_ObjectToUintptr() { trapped("ObjectToUintptr"); }
[[noreturn]] static void trap_ObjectToIntptr() { trapped("ObjectToIntptr"); }
[[noreturn]] static void trap_ObjectToLogical() { trapped("ObjectToLogical"); }
[[noreturn]] static void trap_LogicalToObject() { trapped("LogicalToObject"); }
[[noreturn]] static void trap_DoubleToObject() { trapped("DoubleToObject"); }
[[noreturn]] static void trap_DoubleToObjectWithPrecision() { trapped("DoubleToObjectWithPrecision"); }
[[noreturn]] static void trap_ObjectToDouble() { trapped("ObjectToDouble"); }
[[noreturn]] static void trap_ObjectToString() { trapped("ObjectToString"); }
[[noreturn]] static void trap_ObjectToStringValue() { trapped("ObjectToStringValue"); }
[[noreturn]] static void trap_StringGet() { trapped("StringGet"); }
[[noreturn]] static void trap_StringLength() { trapped("StringLength"); }
[[noreturn]] static void trap_StringData() { trapped("StringData"); }
[[noreturn]] static void trap_NewString() { trapped("NewString"); }
[[noreturn]] static void trap_NewStringFromAsciiz() { trapped("NewStringFromAsciiz"); }
[[noreturn]] static void trap_StringUpper() { trapped("StringUpper"); }
[[noreturn]] static void trap_StringLower() { trapped("StringLower"); }
[[noreturn]] static void trap_IsString() { trapped("IsString"); }
[[noreturn]] static void trap_NewBufferString() { trapped("NewBufferString"); }
[[noreturn]] static void trap_BufferStringLength() { trapped("BufferStringLength"); }
[[noreturn]] static void trap_BufferStringData() { trapped("BufferStringData"); }
[[noreturn]] static void trap_FinishBufferString() { trapped("FinishBufferString"); }
[[noreturn]] static void trap_DirectoryPut() { trapped("DirectoryPut"); }
[[noreturn]] static void trap_DirectoryAt() { trapped("DirectoryAt"); }
[[noreturn]] static void trap_DirectoryRemove() { trapped("DirectoryRemove"); }
[[noreturn]] static void trap_NewDirectory() { trapped("NewDirectory"); }
[[noreturn]] static void trap_IsDirectory() { trapped("IsDirectory"); }
[[noreturn]] static void trap_ArrayAt() { trapped("ArrayAt"); }
[[noreturn]] static void trap_ArrayPut() { trapped("ArrayPut"); }
[[noreturn]] static void trap_ArrayAppend() { trapped("ArrayAppend"); }
[[noreturn]] static void trap_ArrayAppendString() { trapped("ArrayAppendString"); }
[[noreturn]] static void trap_ArraySize() { trapped("ArraySize"); }
[[noreturn]] static void trap_ArrayItems() { trapped("ArrayItems"); }
[[noreturn]] static void trap_ArrayDimension() { trapped("ArrayDimension"); }
[[noreturn]] static void trap_NewArray() { trapped("NewArray"); }
[[noreturn]] static void trap_ArrayOfOne() { trapped("ArrayOfOne"); }
[[noreturn]] static void trap_ArrayOfTwo() { trapped("ArrayOfTwo"); }
[[noreturn]] static void trap_ArrayOfThree() { trapped("ArrayOfThree"); }
[[noreturn]] static void trap_ArrayOfFour() { trapped("ArrayOfFour"); }
[[noreturn]] static void trap_IsArray() { trapped("IsArray"); }
[[noreturn]] static void trap_BufferData() { trapped("BufferData"); }
[[noreturn]] static void trap_BufferLength() { trapped("BufferLength"); }
[[noreturn]] static void trap_NewBuffer() { trapped("NewBuffer"); }
[[noreturn]] static void trap_IsBuffer() { trapped("IsBuffer"); }
[[noreturn]] static void trap_PointerValue() { trapped("PointerValue"); }
[[noreturn]] static void trap_NewPointer() { trapped("NewPointer"); }
[[noreturn]] static void trap_IsPointer() { trapped("IsPointer"); }
[[noreturn]] static void trap_SupplierItem() { trapped("SupplierItem"); }
[[noreturn]] static void trap_SupplierIndex() { trapped("SupplierIndex"); }
[[noreturn]] static void trap_SupplierAvailable() { trapped("SupplierAvailable"); }
[[noreturn]] static void trap_SupplierNext() { trapped("SupplierNext"); }
[[noreturn]] static void trap_NewSupplier() { trapped("NewSupplier"); }
[[noreturn]] static void trap_NewStem() { trapped("NewStem"); }
[[noreturn]] static void trap_SetStemElement() { trapped("SetStemElement"); }
[[noreturn]] static void trap_GetStemElement() { trapped("GetStemElement"); }
[[noreturn]] static void trap_DropStemElement() { trapped("DropStemElement"); }
[[noreturn]] static void trap_SetStemArrayElement() { trapped("SetStemArrayElement"); }
[[noreturn]] static void trap_GetStemArrayElement() { trapped("GetStemArrayElement"); }
[[noreturn]] static void trap_DropStemArrayElement() { trapped("DropStemArrayElement"); }
[[noreturn]] static void trap_GetAllStemElements() { trapped("GetAllStemElements"); }
[[noreturn]] static void trap_GetStemValue() { trapped("GetStemValue"); }
[[noreturn]] static void trap_IsStem() { trapped("IsStem"); }
[[noreturn]] static void trap_RaiseException0() { trapped("RaiseException0"); }
[[noreturn]] static void trap_RaiseException1() { trapped("RaiseException1"); }
[[noreturn]] static void trap_RaiseException2() { trapped("RaiseException2"); }
[[noreturn]] static void trap_RaiseException() { trapped("RaiseException"); }
[[noreturn]] static void trap_RaiseCondition() { trapped("RaiseCondition"); }
[[noreturn]] static void trap_CheckCondition() { trapped("CheckCondition"); }
[[noreturn]] static void trap_GetConditionInfo() { trapped("GetConditionInfo"); }
[[noreturn]] static void trap_DecodeConditionInfo() { trapped("DecodeConditionInfo"); }
[[noreturn]] static void trap_ClearCondition() { trapped("ClearCondition"); }
[[noreturn]] static void trap_ObjectToCSelfScoped() { trapped("ObjectToCSelfScoped"); }
[[noreturn]] static void trap_DisplayCondition() { trapped("DisplayCondition"); }
[[noreturn]] static void trap_MutableBufferData() { trapped("MutableBufferData"); }
[[noreturn]] static void trap_MutableBufferLength() { trapped("MutableBufferLength"); }
[[noreturn]] static void trap_SetMutableBufferLength() { trapped("SetMutableBufferLength"); }
[[noreturn]] static void trap_NewMutableBuffer() { trapped("NewMutableBuffer"); }
[[noreturn]] static void trap_IsMutableBuffer() { trapped("IsMutableBuffer"); }
[[noreturn]] static void trap_MutableBufferCapacity() { trapped("MutableBufferCapacity"); }
[[noreturn]] static void trap_SetMutableBufferCapacity() { trapped("SetMutableBufferCapacity"); }
[[noreturn]] static void trap_VariableReferenceName() { trapped("VariableReferenceName"); }
[[noreturn]] static void trap_VariableReferenceValue() { trapped("VariableReferenceValue"); }
[[noreturn]] static void trap_SetVariableReferenceValue() { trapped("SetVariableReferenceValue"); }
[[noreturn]] static void trap_IsVariableReference() { trapped("IsVariableReference"); }
[[noreturn]] static void trap_StringTablePut() { trapped("StringTablePut"); }
[[noreturn]] static void trap_StringTableAt() { trapped("StringTableAt"); }
[[noreturn]] static void trap_StringTableRemove() { trapped("StringTableRemove"); }
[[noreturn]] static void trap_NewStringTable() { trapped("NewStringTable"); }
[[noreturn]] static void trap_IsStringTable() { trapped("IsStringTable"); }
[[noreturn]] static void trap_SendMessageScoped() { trapped("SendMessageScoped"); }
[[noreturn]] static void trap_GetInterpreterInstance() { trapped("GetInterpreterInstance"); }
static void installTraps(RexxThreadInterface &t) {
    t.DetachThread = reinterpret_cast<decltype(t.DetachThread)>(&trap_DetachThread);
    t.HaltThread = reinterpret_cast<decltype(t.HaltThread)>(&trap_HaltThread);
    t.SetThreadTrace = reinterpret_cast<decltype(t.SetThreadTrace)>(&trap_SetThreadTrace);
    t.RequestGlobalReference = reinterpret_cast<decltype(t.RequestGlobalReference)>(&trap_RequestGlobalReference);
    t.ReleaseGlobalReference = reinterpret_cast<decltype(t.ReleaseGlobalReference)>(&trap_ReleaseGlobalReference);
    t.ReleaseLocalReference = reinterpret_cast<decltype(t.ReleaseLocalReference)>(&trap_ReleaseLocalReference);
    t.SendMessage = reinterpret_cast<decltype(t.SendMessage)>(&trap_SendMessage);
    t.SendMessage0 = reinterpret_cast<decltype(t.SendMessage0)>(&trap_SendMessage0);
    t.SendMessage1 = reinterpret_cast<decltype(t.SendMessage1)>(&trap_SendMessage1);
    t.SendMessage2 = reinterpret_cast<decltype(t.SendMessage2)>(&trap_SendMessage2);
    t.GetLocalEnvironment = reinterpret_cast<decltype(t.GetLocalEnvironment)>(&trap_GetLocalEnvironment);
    t.GetGlobalEnvironment = reinterpret_cast<decltype(t.GetGlobalEnvironment)>(&trap_GetGlobalEnvironment);
    t.IsInstanceOf = reinterpret_cast<decltype(t.IsInstanceOf)>(&trap_IsInstanceOf);
    t.IsOfType = reinterpret_cast<decltype(t.IsOfType)>(&trap_IsOfType);
    t.HasMethod = reinterpret_cast<decltype(t.HasMethod)>(&trap_HasMethod);
    t.LoadPackage = reinterpret_cast<decltype(t.LoadPackage)>(&trap_LoadPackage);
    t.LoadPackageFromData = reinterpret_cast<decltype(t.LoadPackageFromData)>(&trap_LoadPackageFromData);
    t.LoadLibrary = reinterpret_cast<decltype(t.LoadLibrary)>(&trap_LoadLibrary);
    t.RegisterLibrary = reinterpret_cast<decltype(t.RegisterLibrary)>(&trap_RegisterLibrary);
    t.FindClass = reinterpret_cast<decltype(t.FindClass)>(&trap_FindClass);
    t.FindPackageClass = reinterpret_cast<decltype(t.FindPackageClass)>(&trap_FindPackageClass);
    t.GetPackageRoutines = reinterpret_cast<decltype(t.GetPackageRoutines)>(&trap_GetPackageRoutines);
    t.GetPackagePublicRoutines = reinterpret_cast<decltype(t.GetPackagePublicRoutines)>(&trap_GetPackagePublicRoutines);
    t.GetPackageClasses = reinterpret_cast<decltype(t.GetPackageClasses)>(&trap_GetPackageClasses);
    t.GetPackagePublicClasses = reinterpret_cast<decltype(t.GetPackagePublicClasses)>(&trap_GetPackagePublicClasses);
    t.GetPackageMethods = reinterpret_cast<decltype(t.GetPackageMethods)>(&trap_GetPackageMethods);
    t.CallRoutine = reinterpret_cast<decltype(t.CallRoutine)>(&trap_CallRoutine);
    t.CallProgram = reinterpret_cast<decltype(t.CallProgram)>(&trap_CallProgram);
    t.NewMethod = reinterpret_cast<decltype(t.NewMethod)>(&trap_NewMethod);
    t.NewRoutine = reinterpret_cast<decltype(t.NewRoutine)>(&trap_NewRoutine);
    t.IsRoutine = reinterpret_cast<decltype(t.IsRoutine)>(&trap_IsRoutine);
    t.IsMethod = reinterpret_cast<decltype(t.IsMethod)>(&trap_IsMethod);
    t.GetRoutinePackage = reinterpret_cast<decltype(t.GetRoutinePackage)>(&trap_GetRoutinePackage);
    t.GetMethodPackage = reinterpret_cast<decltype(t.GetMethodPackage)>(&trap_GetMethodPackage);
    t.ObjectToCSelf = reinterpret_cast<decltype(t.ObjectToCSelf)>(&trap_ObjectToCSelf);
    t.WholeNumberToObject = reinterpret_cast<decltype(t.WholeNumberToObject)>(&trap_WholeNumberToObject);
    t.UintptrToObject = reinterpret_cast<decltype(t.UintptrToObject)>(&trap_UintptrToObject);
    t.IntptrToObject = reinterpret_cast<decltype(t.IntptrToObject)>(&trap_IntptrToObject);
    t.ValueToObject = reinterpret_cast<decltype(t.ValueToObject)>(&trap_ValueToObject);
    t.ValuesToObject = reinterpret_cast<decltype(t.ValuesToObject)>(&trap_ValuesToObject);
    t.ObjectToValue = reinterpret_cast<decltype(t.ObjectToValue)>(&trap_ObjectToValue);
    t.StringSizeToObject = reinterpret_cast<decltype(t.StringSizeToObject)>(&trap_StringSizeToObject);
    t.ObjectToWholeNumber = reinterpret_cast<decltype(t.ObjectToWholeNumber)>(&trap_ObjectToWholeNumber);
    t.ObjectToStringSize = reinterpret_cast<decltype(t.ObjectToStringSize)>(&trap_ObjectToStringSize);
    t.Int64ToObject = reinterpret_cast<decltype(t.Int64ToObject)>(&trap_Int64ToObject);
    t.UnsignedInt64ToObject = reinterpret_cast<decltype(t.UnsignedInt64ToObject)>(&trap_UnsignedInt64ToObject);
    t.ObjectToInt64 = reinterpret_cast<decltype(t.ObjectToInt64)>(&trap_ObjectToInt64);
    t.ObjectToUnsignedInt64 = reinterpret_cast<decltype(t.ObjectToUnsignedInt64)>(&trap_ObjectToUnsignedInt64);
    t.Int32ToObject = reinterpret_cast<decltype(t.Int32ToObject)>(&trap_Int32ToObject);
    t.UnsignedInt32ToObject = reinterpret_cast<decltype(t.UnsignedInt32ToObject)>(&trap_UnsignedInt32ToObject);
    t.ObjectToInt32 = reinterpret_cast<decltype(t.ObjectToInt32)>(&trap_ObjectToInt32);
    t.ObjectToUnsignedInt32 = reinterpret_cast<decltype(t.ObjectToUnsignedInt32)>(&trap_ObjectToUnsignedInt32);
    t.ObjectToUintptr = reinterpret_cast<decltype(t.ObjectToUintptr)>(&trap_ObjectToUintptr);
    t.ObjectToIntptr = reinterpret_cast<decltype(t.ObjectToIntptr)>(&trap_ObjectToIntptr);
    t.ObjectToLogical = reinterpret_cast<decltype(t.ObjectToLogical)>(&trap_ObjectToLogical);
    t.LogicalToObject = reinterpret_cast<decltype(t.LogicalToObject)>(&trap_LogicalToObject);
    t.DoubleToObject = reinterpret_cast<decltype(t.DoubleToObject)>(&trap_DoubleToObject);
    t.DoubleToObjectWithPrecision = reinterpret_cast<decltype(t.DoubleToObjectWithPrecision)>(&trap_DoubleToObjectWithPrecision);
    t.ObjectToDouble = reinterpret_cast<decltype(t.ObjectToDouble)>(&trap_ObjectToDouble);
    t.ObjectToString = reinterpret_cast<decltype(t.ObjectToString)>(&trap_ObjectToString);
    t.ObjectToStringValue = reinterpret_cast<decltype(t.ObjectToStringValue)>(&trap_ObjectToStringValue);
    t.StringGet = reinterpret_cast<decltype(t.StringGet)>(&trap_StringGet);
    t.StringLength = reinterpret_cast<decltype(t.StringLength)>(&trap_StringLength);
    t.StringData = reinterpret_cast<decltype(t.StringData)>(&trap_StringData);
    t.NewString = reinterpret_cast<decltype(t.NewString)>(&trap_NewString);
    t.NewStringFromAsciiz = reinterpret_cast<decltype(t.NewStringFromAsciiz)>(&trap_NewStringFromAsciiz);
    t.StringUpper = reinterpret_cast<decltype(t.StringUpper)>(&trap_StringUpper);
    t.StringLower = reinterpret_cast<decltype(t.StringLower)>(&trap_StringLower);
    t.IsString = reinterpret_cast<decltype(t.IsString)>(&trap_IsString);
    t.NewBufferString = reinterpret_cast<decltype(t.NewBufferString)>(&trap_NewBufferString);
    t.BufferStringLength = reinterpret_cast<decltype(t.BufferStringLength)>(&trap_BufferStringLength);
    t.BufferStringData = reinterpret_cast<decltype(t.BufferStringData)>(&trap_BufferStringData);
    t.FinishBufferString = reinterpret_cast<decltype(t.FinishBufferString)>(&trap_FinishBufferString);
    t.DirectoryPut = reinterpret_cast<decltype(t.DirectoryPut)>(&trap_DirectoryPut);
    t.DirectoryAt = reinterpret_cast<decltype(t.DirectoryAt)>(&trap_DirectoryAt);
    t.DirectoryRemove = reinterpret_cast<decltype(t.DirectoryRemove)>(&trap_DirectoryRemove);
    t.NewDirectory = reinterpret_cast<decltype(t.NewDirectory)>(&trap_NewDirectory);
    t.IsDirectory = reinterpret_cast<decltype(t.IsDirectory)>(&trap_IsDirectory);
    t.ArrayAt = reinterpret_cast<decltype(t.ArrayAt)>(&trap_ArrayAt);
    t.ArrayPut = reinterpret_cast<decltype(t.ArrayPut)>(&trap_ArrayPut);
    t.ArrayAppend = reinterpret_cast<decltype(t.ArrayAppend)>(&trap_ArrayAppend);
    t.ArrayAppendString = reinterpret_cast<decltype(t.ArrayAppendString)>(&trap_ArrayAppendString);
    t.ArraySize = reinterpret_cast<decltype(t.ArraySize)>(&trap_ArraySize);
    t.ArrayItems = reinterpret_cast<decltype(t.ArrayItems)>(&trap_ArrayItems);
    t.ArrayDimension = reinterpret_cast<decltype(t.ArrayDimension)>(&trap_ArrayDimension);
    t.NewArray = reinterpret_cast<decltype(t.NewArray)>(&trap_NewArray);
    t.ArrayOfOne = reinterpret_cast<decltype(t.ArrayOfOne)>(&trap_ArrayOfOne);
    t.ArrayOfTwo = reinterpret_cast<decltype(t.ArrayOfTwo)>(&trap_ArrayOfTwo);
    t.ArrayOfThree = reinterpret_cast<decltype(t.ArrayOfThree)>(&trap_ArrayOfThree);
    t.ArrayOfFour = reinterpret_cast<decltype(t.ArrayOfFour)>(&trap_ArrayOfFour);
    t.IsArray = reinterpret_cast<decltype(t.IsArray)>(&trap_IsArray);
    t.BufferData = reinterpret_cast<decltype(t.BufferData)>(&trap_BufferData);
    t.BufferLength = reinterpret_cast<decltype(t.BufferLength)>(&trap_BufferLength);
    t.NewBuffer = reinterpret_cast<decltype(t.NewBuffer)>(&trap_NewBuffer);
    t.IsBuffer = reinterpret_cast<decltype(t.IsBuffer)>(&trap_IsBuffer);
    t.PointerValue = reinterpret_cast<decltype(t.PointerValue)>(&trap_PointerValue);
    t.NewPointer = reinterpret_cast<decltype(t.NewPointer)>(&trap_NewPointer);
    t.IsPointer = reinterpret_cast<decltype(t.IsPointer)>(&trap_IsPointer);
    t.SupplierItem = reinterpret_cast<decltype(t.SupplierItem)>(&trap_SupplierItem);
    t.SupplierIndex = reinterpret_cast<decltype(t.SupplierIndex)>(&trap_SupplierIndex);
    t.SupplierAvailable = reinterpret_cast<decltype(t.SupplierAvailable)>(&trap_SupplierAvailable);
    t.SupplierNext = reinterpret_cast<decltype(t.SupplierNext)>(&trap_SupplierNext);
    t.NewSupplier = reinterpret_cast<decltype(t.NewSupplier)>(&trap_NewSupplier);
    t.NewStem = reinterpret_cast<decltype(t.NewStem)>(&trap_NewStem);
    t.SetStemElement = reinterpret_cast<decltype(t.SetStemElement)>(&trap_SetStemElement);
    t.GetStemElement = reinterpret_cast<decltype(t.GetStemElement)>(&trap_GetStemElement);
    t.DropStemElement = reinterpret_cast<decltype(t.DropStemElement)>(&trap_DropStemElement);
    t.SetStemArrayElement = reinterpret_cast<decltype(t.SetStemArrayElement)>(&trap_SetStemArrayElement);
    t.GetStemArrayElement = reinterpret_cast<decltype(t.GetStemArrayElement)>(&trap_GetStemArrayElement);
    t.DropStemArrayElement = reinterpret_cast<decltype(t.DropStemArrayElement)>(&trap_DropStemArrayElement);
    t.GetAllStemElements = reinterpret_cast<decltype(t.GetAllStemElements)>(&trap_GetAllStemElements);
    t.GetStemValue = reinterpret_cast<decltype(t.GetStemValue)>(&trap_GetStemValue);
    t.IsStem = reinterpret_cast<decltype(t.IsStem)>(&trap_IsStem);
    t.RaiseException0 = reinterpret_cast<decltype(t.RaiseException0)>(&trap_RaiseException0);
    t.RaiseException1 = reinterpret_cast<decltype(t.RaiseException1)>(&trap_RaiseException1);
    t.RaiseException2 = reinterpret_cast<decltype(t.RaiseException2)>(&trap_RaiseException2);
    t.RaiseException = reinterpret_cast<decltype(t.RaiseException)>(&trap_RaiseException);
    t.RaiseCondition = reinterpret_cast<decltype(t.RaiseCondition)>(&trap_RaiseCondition);
    t.CheckCondition = reinterpret_cast<decltype(t.CheckCondition)>(&trap_CheckCondition);
    t.GetConditionInfo = reinterpret_cast<decltype(t.GetConditionInfo)>(&trap_GetConditionInfo);
    t.DecodeConditionInfo = reinterpret_cast<decltype(t.DecodeConditionInfo)>(&trap_DecodeConditionInfo);
    t.ClearCondition = reinterpret_cast<decltype(t.ClearCondition)>(&trap_ClearCondition);
    t.ObjectToCSelfScoped = reinterpret_cast<decltype(t.ObjectToCSelfScoped)>(&trap_ObjectToCSelfScoped);
    t.DisplayCondition = reinterpret_cast<decltype(t.DisplayCondition)>(&trap_DisplayCondition);
    t.MutableBufferData = reinterpret_cast<decltype(t.MutableBufferData)>(&trap_MutableBufferData);
    t.MutableBufferLength = reinterpret_cast<decltype(t.MutableBufferLength)>(&trap_MutableBufferLength);
    t.SetMutableBufferLength = reinterpret_cast<decltype(t.SetMutableBufferLength)>(&trap_SetMutableBufferLength);
    t.NewMutableBuffer = reinterpret_cast<decltype(t.NewMutableBuffer)>(&trap_NewMutableBuffer);
    t.IsMutableBuffer = reinterpret_cast<decltype(t.IsMutableBuffer)>(&trap_IsMutableBuffer);
    t.MutableBufferCapacity = reinterpret_cast<decltype(t.MutableBufferCapacity)>(&trap_MutableBufferCapacity);
    t.SetMutableBufferCapacity = reinterpret_cast<decltype(t.SetMutableBufferCapacity)>(&trap_SetMutableBufferCapacity);
    t.VariableReferenceName = reinterpret_cast<decltype(t.VariableReferenceName)>(&trap_VariableReferenceName);
    t.VariableReferenceValue = reinterpret_cast<decltype(t.VariableReferenceValue)>(&trap_VariableReferenceValue);
    t.SetVariableReferenceValue = reinterpret_cast<decltype(t.SetVariableReferenceValue)>(&trap_SetVariableReferenceValue);
    t.IsVariableReference = reinterpret_cast<decltype(t.IsVariableReference)>(&trap_IsVariableReference);
    t.StringTablePut = reinterpret_cast<decltype(t.StringTablePut)>(&trap_StringTablePut);
    t.StringTableAt = reinterpret_cast<decltype(t.StringTableAt)>(&trap_StringTableAt);
    t.StringTableRemove = reinterpret_cast<decltype(t.StringTableRemove)>(&trap_StringTableRemove);
    t.NewStringTable = reinterpret_cast<decltype(t.NewStringTable)>(&trap_NewStringTable);
    t.IsStringTable = reinterpret_cast<decltype(t.IsStringTable)>(&trap_IsStringTable);
    t.SendMessageScoped = reinterpret_cast<decltype(t.SendMessageScoped)>(&trap_SendMessageScoped);
    t.GetInterpreterInstance = reinterpret_cast<decltype(t.GetInterpreterInstance)>(&trap_GetInterpreterInstance);
}
