struct RexxThreadInterface
{
     wholenumber_t interfaceVersion;    

     void             ( *DetachThread)(RexxThreadContext *);
     void             ( *HaltThread)(RexxThreadContext *);
     void             ( *SetThreadTrace)(RexxThreadContext *, logical_t);
     RexxObjectPtr( *RequestGlobalReference)(RexxThreadContext *, RexxObjectPtr);
     void             ( *ReleaseGlobalReference)(RexxThreadContext *, RexxObjectPtr);
     void             ( *ReleaseLocalReference)(RexxThreadContext *, RexxObjectPtr);

     RexxObjectPtr( * SendMessage)(RexxThreadContext * , RexxObjectPtr, CSTRING, RexxArrayObject);
     RexxObjectPtr( * SendMessage0)(RexxThreadContext * , RexxObjectPtr, CSTRING);
     RexxObjectPtr( * SendMessage1)(RexxThreadContext * , RexxObjectPtr, CSTRING, RexxObjectPtr);
     RexxObjectPtr( * SendMessage2)(RexxThreadContext * , RexxObjectPtr, CSTRING, RexxObjectPtr, RexxObjectPtr);

     RexxDirectoryObject( * GetLocalEnvironment)(RexxThreadContext * );
     RexxDirectoryObject( * GetGlobalEnvironment)(RexxThreadContext * );

     logical_t( * IsInstanceOf)(RexxThreadContext * , RexxObjectPtr, RexxClassObject);
     logical_t( * IsOfType)(RexxThreadContext * , RexxObjectPtr, CSTRING);
     logical_t( * HasMethod)(RexxThreadContext * , RexxObjectPtr, CSTRING);

     RexxPackageObject( * LoadPackage)(RexxThreadContext * , CSTRING d);
     RexxPackageObject( * LoadPackageFromData)(RexxThreadContext * , CSTRING n, CSTRING d, size_t l);
     logical_t( * LoadLibrary)(RexxThreadContext * , CSTRING n);
     logical_t( * RegisterLibrary)(RexxThreadContext * , CSTRING n, RexxPackageEntry *);
     RexxClassObject( * FindClass)(RexxThreadContext * , CSTRING);
     RexxClassObject( * FindPackageClass)(RexxThreadContext * , RexxPackageObject, CSTRING);
     RexxDirectoryObject( * GetPackageRoutines)(RexxThreadContext * , RexxPackageObject);
     RexxDirectoryObject( * GetPackagePublicRoutines)(RexxThreadContext * , RexxPackageObject);
     RexxDirectoryObject( * GetPackageClasses)(RexxThreadContext * , RexxPackageObject);
     RexxDirectoryObject( * GetPackagePublicClasses)(RexxThreadContext * , RexxPackageObject);
     RexxDirectoryObject( * GetPackageMethods)(RexxThreadContext * , RexxPackageObject);
     RexxObjectPtr( * CallRoutine)(RexxThreadContext * , RexxRoutineObject, RexxArrayObject);
     RexxObjectPtr( * CallProgram)(RexxThreadContext * , CSTRING, RexxArrayObject);

     RexxMethodObject( * NewMethod)(RexxThreadContext * , CSTRING, CSTRING, size_t);
     RexxRoutineObject( * NewRoutine)(RexxThreadContext * , CSTRING, CSTRING, size_t);
     logical_t( * IsRoutine)(RexxThreadContext * , RexxObjectPtr);
     logical_t( * IsMethod)(RexxThreadContext * , RexxObjectPtr);
     RexxPackageObject( * GetRoutinePackage)(RexxThreadContext * , RexxRoutineObject);
     RexxPackageObject( * GetMethodPackage)(RexxThreadContext * , RexxMethodObject);

     POINTER( * ObjectToCSelf)(RexxThreadContext * , RexxObjectPtr);
     RexxObjectPtr( * WholeNumberToObject)(RexxThreadContext * , wholenumber_t);
     RexxObjectPtr( * UintptrToObject)(RexxThreadContext * , uintptr_t);
     RexxObjectPtr( * IntptrToObject)(RexxThreadContext * , intptr_t);
     RexxObjectPtr( * ValueToObject)(RexxThreadContext * , ValueDescriptor * );
     RexxArrayObject( * ValuesToObject)(RexxThreadContext * , ValueDescriptor * , size_t count);
     logical_t( * ObjectToValue)(RexxThreadContext * , RexxObjectPtr, ValueDescriptor * );
     RexxObjectPtr( * StringSizeToObject)(RexxThreadContext * , stringsize_t);
     logical_t( * ObjectToWholeNumber)(RexxThreadContext * , RexxObjectPtr, wholenumber_t * );
     logical_t( * ObjectToStringSize)(RexxThreadContext * , RexxObjectPtr, stringsize_t * );
     RexxObjectPtr( * Int64ToObject)(RexxThreadContext * , int64_t);
     RexxObjectPtr( * UnsignedInt64ToObject)(RexxThreadContext * , uint64_t);
     logical_t( * ObjectToInt64)(RexxThreadContext * , RexxObjectPtr, int64_t * );
     logical_t( * ObjectToUnsignedInt64)(RexxThreadContext * , RexxObjectPtr, uint64_t * );
     RexxObjectPtr( * Int32ToObject)(RexxThreadContext * , int32_t);
     RexxObjectPtr( * UnsignedInt32ToObject)(RexxThreadContext * , uint32_t);
     logical_t( * ObjectToInt32)(RexxThreadContext * , RexxObjectPtr, int32_t * );
     logical_t( * ObjectToUnsignedInt32)(RexxThreadContext * , RexxObjectPtr, uint32_t * );
     logical_t( * ObjectToUintptr)(RexxThreadContext * , RexxObjectPtr, uintptr_t * );
     logical_t( * ObjectToIntptr)(RexxThreadContext * , RexxObjectPtr, intptr_t * );
     logical_t( * ObjectToLogical)(RexxThreadContext * , RexxObjectPtr, logical_t * );
     RexxObjectPtr( * LogicalToObject)(RexxThreadContext * , logical_t);
     RexxObjectPtr( * DoubleToObject)(RexxThreadContext * , double);
     RexxObjectPtr( * DoubleToObjectWithPrecision)(RexxThreadContext * , double, size_t precision);
     logical_t( * ObjectToDouble)(RexxThreadContext * , RexxObjectPtr, double *);

     RexxStringObject( * ObjectToString)(RexxThreadContext * , RexxObjectPtr);
     CSTRING( * ObjectToStringValue)(RexxThreadContext * , RexxObjectPtr);
     size_t( * StringGet)(RexxThreadContext * , RexxStringObject, size_t, POINTER, size_t);
     size_t( * StringLength)(RexxThreadContext * , RexxStringObject);
     CSTRING( * StringData)(RexxThreadContext * , RexxStringObject);
     RexxStringObject( * NewString)(RexxThreadContext * , CSTRING, size_t);
     RexxStringObject( * NewStringFromAsciiz)(RexxThreadContext * , CSTRING);
     RexxStringObject( * StringUpper)(RexxThreadContext * , RexxStringObject);
     RexxStringObject( * StringLower)(RexxThreadContext * , RexxStringObject);
     logical_t( * IsString)(RexxThreadContext * , RexxObjectPtr);

     RexxBufferStringObject( * NewBufferString)(RexxThreadContext * , size_t);
     size_t( * BufferStringLength)(RexxThreadContext * , RexxBufferStringObject);
     POINTER( * BufferStringData)(RexxThreadContext * , RexxBufferStringObject);
     RexxStringObject( * FinishBufferString)(RexxThreadContext * , RexxBufferStringObject, size_t);

     void             ( *DirectoryPut)(RexxThreadContext *, RexxDirectoryObject, RexxObjectPtr, CSTRING);
     RexxObjectPtr( *DirectoryAt)(RexxThreadContext *, RexxDirectoryObject, CSTRING);
     RexxObjectPtr( *DirectoryRemove)(RexxThreadContext *, RexxDirectoryObject, CSTRING);
     RexxDirectoryObject( *NewDirectory)(RexxThreadContext *);
     logical_t( *IsDirectory)(RexxThreadContext *, RexxObjectPtr);

     RexxObjectPtr( *ArrayAt)(RexxThreadContext *, RexxArrayObject, size_t);
     void            ( *ArrayPut)(RexxThreadContext *, RexxArrayObject, RexxObjectPtr, size_t);
     size_t( *ArrayAppend)(RexxThreadContext *, RexxArrayObject, RexxObjectPtr);
     size_t( *ArrayAppendString)(RexxThreadContext *, RexxArrayObject, CSTRING, size_t);
     size_t( *ArraySize)(RexxThreadContext *, RexxArrayObject);
     size_t( *ArrayItems)(RexxThreadContext *, RexxArrayObject);
     size_t( *ArrayDimension)(RexxThreadContext *, RexxArrayObject);
     RexxArrayObject( *NewArray)(RexxThreadContext *, size_t);
     RexxArrayObject( *ArrayOfOne)(RexxThreadContext *, RexxObjectPtr);
     RexxArrayObject( *ArrayOfTwo)(RexxThreadContext *, RexxObjectPtr, RexxObjectPtr);
     RexxArrayObject( *ArrayOfThree)(RexxThreadContext *, RexxObjectPtr, RexxObjectPtr, RexxObjectPtr);
     RexxArrayObject( *ArrayOfFour)(RexxThreadContext *, RexxObjectPtr, RexxObjectPtr, RexxObjectPtr, RexxObjectPtr);
     logical_t( *IsArray)(RexxThreadContext *, RexxObjectPtr);

     POINTER( *BufferData)(RexxThreadContext *, RexxBufferObject);
     size_t( *BufferLength)(RexxThreadContext *, RexxBufferObject);
     RexxBufferObject( *NewBuffer)(RexxThreadContext *, size_t);
     logical_t( *IsBuffer)(RexxThreadContext *, RexxObjectPtr);

     POINTER( *PointerValue)(RexxThreadContext *, RexxPointerObject);
     RexxPointerObject( *NewPointer)(RexxThreadContext *, POINTER);
     logical_t( *IsPointer)(RexxThreadContext *, RexxObjectPtr);

     RexxObjectPtr( *SupplierItem)(RexxThreadContext *, RexxSupplierObject);
     RexxObjectPtr( *SupplierIndex)(RexxThreadContext *, RexxSupplierObject);
     logical_t( *SupplierAvailable)(RexxThreadContext *, RexxSupplierObject);
     void             ( *SupplierNext)(RexxThreadContext *, RexxSupplierObject);
     RexxSupplierObject( *NewSupplier)(RexxThreadContext *, RexxArrayObject values, RexxArrayObject names);

     RexxStemObject( *NewStem)(RexxThreadContext *, CSTRING);
     void             ( *SetStemElement)(RexxThreadContext *, RexxStemObject, CSTRING, RexxObjectPtr);
     RexxObjectPtr( *GetStemElement)(RexxThreadContext *, RexxStemObject, CSTRING);
     void             ( *DropStemElement)(RexxThreadContext *, RexxStemObject, CSTRING);
     void             ( *SetStemArrayElement)(RexxThreadContext *, RexxStemObject, size_t, RexxObjectPtr);
     RexxObjectPtr( *GetStemArrayElement)(RexxThreadContext *, RexxStemObject, size_t);
     void             ( *DropStemArrayElement)(RexxThreadContext *, RexxStemObject, size_t);
     RexxDirectoryObject( *GetAllStemElements)(RexxThreadContext *, RexxStemObject);
     RexxObjectPtr( *GetStemValue)(RexxThreadContext *, RexxStemObject);
     logical_t( *IsStem)(RexxThreadContext *, RexxObjectPtr);

     void             ( *RaiseException0)(RexxThreadContext *, size_t);
     void             ( *RaiseException1)(RexxThreadContext *, size_t, RexxObjectPtr);
     void             ( *RaiseException2)(RexxThreadContext *, size_t, RexxObjectPtr, RexxObjectPtr);
     void             ( *RaiseException)(RexxThreadContext *, size_t, RexxArrayObject);
     void             ( *RaiseCondition)(RexxThreadContext *, CSTRING, RexxStringObject, RexxObjectPtr, RexxObjectPtr);
     logical_t( *CheckCondition)(RexxThreadContext *);
     RexxDirectoryObject( *GetConditionInfo)(RexxThreadContext *);
     void             ( *DecodeConditionInfo)(RexxThreadContext *, RexxDirectoryObject, RexxCondition *);
     void             ( *ClearCondition)(RexxThreadContext *);

     RexxObjectPtr    RexxNil;
     RexxObjectPtr    RexxTrue;
     RexxObjectPtr    RexxFalse;
     RexxStringObject RexxNullString;

     POINTER( *ObjectToCSelfScoped)(RexxThreadContext *, RexxObjectPtr, RexxObjectPtr);
     wholenumber_t( *DisplayCondition)(RexxThreadContext *);

     POINTER( *MutableBufferData)(RexxThreadContext *, RexxMutableBufferObject);
     size_t( *MutableBufferLength)(RexxThreadContext *, RexxMutableBufferObject);
     size_t( *SetMutableBufferLength)(RexxThreadContext *, RexxMutableBufferObject, size_t);
     RexxMutableBufferObject( *NewMutableBuffer)(RexxThreadContext *, size_t);
     logical_t( *IsMutableBuffer)(RexxThreadContext *, RexxObjectPtr);
     size_t( *MutableBufferCapacity)(RexxThreadContext *, RexxMutableBufferObject);
     POINTER( *SetMutableBufferCapacity)(RexxThreadContext *, RexxMutableBufferObject, size_t);

     RexxStringObject( *VariableReferenceName)(RexxThreadContext *, RexxVariableReferenceObject);
     RexxObjectPtr( *VariableReferenceValue)(RexxThreadContext *, RexxVariableReferenceObject);
     void              ( *SetVariableReferenceValue)(RexxThreadContext *, RexxVariableReferenceObject, RexxObjectPtr);
     logical_t( *IsVariableReference)(RexxThreadContext *, RexxObjectPtr);

     void             ( *StringTablePut)(RexxThreadContext *, RexxStringTableObject, RexxObjectPtr, CSTRING);
     RexxObjectPtr( *StringTableAt)(RexxThreadContext *, RexxStringTableObject, CSTRING);
     RexxObjectPtr( *StringTableRemove)(RexxThreadContext *, RexxStringTableObject, CSTRING);
     RexxStringTableObject( *NewStringTable)(RexxThreadContext *);
     logical_t( *IsStringTable)(RexxThreadContext *, RexxObjectPtr);
     RexxObjectPtr( *SendMessageScoped)(RexxThreadContext *, RexxObjectPtr, CSTRING, RexxClassObject, RexxArrayObject);
     RexxInstance *( *GetInterpreterInstance)(RexxThreadContext *);

};

struct MethodContextInterface
{
     wholenumber_t interfaceVersion;    

     RexxArrayObject( *GetArguments)(RexxMethodContext *);
     RexxObjectPtr( *GetArgument)(RexxMethodContext *, size_t);
     CSTRING( *GetMessageName)(RexxMethodContext *);
     RexxMethodObject( *GetMethod)(RexxMethodContext *);
     RexxObjectPtr( *GetSelf)(RexxMethodContext *);
     RexxClassObject( *GetSuper)(RexxMethodContext *);
     RexxObjectPtr( *GetScope)(RexxMethodContext *);
     void             ( *SetObjectVariable)(RexxMethodContext *, CSTRING, RexxObjectPtr);
     RexxObjectPtr( *GetObjectVariable)(RexxMethodContext *, CSTRING);
     void             ( *DropObjectVariable)(RexxMethodContext *, CSTRING);
     RexxObjectPtr( *ForwardMessage)(RexxMethodContext *, RexxObjectPtr, CSTRING, RexxClassObject, RexxArrayObject);
     void             ( *SetGuardOn)(RexxMethodContext *);
     void             ( *SetGuardOff)(RexxMethodContext *);
     RexxClassObject( *FindContextClass)(RexxMethodContext *, CSTRING);
     POINTER( *GetCSelf)(RexxMethodContext *);
     POINTER( *AllocateObjectMemory)(RexxMethodContext *, size_t);
     void             ( *FreeObjectMemory)(RexxMethodContext *, POINTER);
     POINTER( *ReallocateObjectMemory)(RexxMethodContext *, POINTER, size_t);
     RexxVariableReferenceObject( *GetObjectVariableReference)(RexxMethodContext *, CSTRING);
     RexxObjectPtr( *SetGuardOnWhenUpdated)(RexxMethodContext *, CSTRING);
     RexxObjectPtr( *SetGuardOffWhenUpdated)(RexxMethodContext *, CSTRING);
     void ( *ThrowException0)(RexxMethodContext *, size_t);
     void ( *ThrowException1)(RexxMethodContext *, size_t, RexxObjectPtr);
     void ( *ThrowException2)(RexxMethodContext *, size_t, RexxObjectPtr, RexxObjectPtr);
     void ( *ThrowException)(RexxMethodContext *, size_t, RexxArrayObject);
     void ( *ThrowCondition)(RexxMethodContext *, CSTRING, RexxStringObject, RexxObjectPtr, RexxObjectPtr);
};

struct CallContextInterface
{
     wholenumber_t interfaceVersion;    

     RexxArrayObject( *GetArguments)(RexxCallContext *);
     RexxObjectPtr( *GetArgument)(RexxCallContext *, size_t);
     CSTRING( *GetRoutineName)(RexxCallContext *);
     RexxRoutineObject( *GetRoutine)(RexxCallContext *);
     void             ( *SetContextVariable)(RexxCallContext *, CSTRING, RexxObjectPtr);
     RexxObjectPtr( *GetContextVariable)(RexxCallContext *, CSTRING);
     void             ( *DropContextVariable)(RexxCallContext *, CSTRING);
     RexxDirectoryObject( *GetAllContextVariables)(RexxCallContext *);
     RexxStemObject( *ResolveStemVariable)(RexxCallContext *, RexxObjectPtr);
     void             ( *InvalidRoutine)(RexxCallContext *);
     stringsize_t( *GetContextDigits)(RexxCallContext *);
     stringsize_t( *GetContextFuzz)(RexxCallContext *);
     logical_t( *GetContextForm)(RexxCallContext *);
     RexxObjectPtr( *GetCallerContext)(RexxCallContext *);
     RexxClassObject( *FindContextClass)(RexxCallContext *, CSTRING);
     RexxVariableReferenceObject( * GetContextVariableReference)(RexxCallContext * , CSTRING);
     void ( *ThrowException0)(RexxCallContext *, size_t);
     void ( *ThrowException1)(RexxCallContext *, size_t, RexxObjectPtr);
     void ( *ThrowException2)(RexxCallContext *, size_t, RexxObjectPtr, RexxObjectPtr);
     void ( *ThrowException)(RexxCallContext *, size_t, RexxArrayObject);
     void ( *ThrowCondition)(RexxCallContext *, CSTRING, RexxStringObject, RexxObjectPtr, RexxObjectPtr);
};

struct ExitContextInterface
{
     wholenumber_t interfaceVersion;    
     void             ( *SetContextVariable)(RexxExitContext *, CSTRING, RexxObjectPtr);
     RexxObjectPtr( *GetContextVariable)(RexxExitContext *, CSTRING);
     void             ( *DropContextVariable)(RexxExitContext *, CSTRING);
     RexxDirectoryObject( *GetAllContextVariables)(RexxExitContext *);
     RexxObjectPtr( *GetCallerContext)(RexxExitContext *);
     RexxVariableReferenceObject( * GetContextVariableReference)(RexxExitContext * , CSTRING);
     void ( *ThrowException0)(RexxExitContext *, size_t);
     void ( *ThrowException1)(RexxExitContext *, size_t, RexxObjectPtr);
     void ( *ThrowException2)(RexxExitContext *, size_t, RexxObjectPtr, RexxObjectPtr);
     void ( *ThrowException)(RexxExitContext *, size_t, RexxArrayObject);
     void ( *ThrowCondition)(RexxExitContext *, CSTRING, RexxStringObject, RexxObjectPtr, RexxObjectPtr);
};

struct IORedirectorInterface
{
    wholenumber_t interfaceVersion;    

    void    ( *ReadInput)(RexxIORedirectorContext *, CSTRING *, size_t *);
    void    ( *ReadInputBuffer)(RexxIORedirectorContext *, CSTRING *, size_t *);
    void    ( *WriteOutput)(RexxIORedirectorContext *, CSTRING, size_t);
    void    ( *WriteError)(RexxIORedirectorContext *, CSTRING, size_t);
    void    ( *WriteOutputBuffer)(RexxIORedirectorContext *, CSTRING, size_t);
    void    ( *WriteErrorBuffer)(RexxIORedirectorContext *, CSTRING, size_t);
    logical_t ( *IsInputRedirected)(RexxIORedirectorContext *);
    logical_t ( *IsOutputRedirected)(RexxIORedirectorContext *);
    logical_t ( *IsErrorRedirected)(RexxIORedirectorContext *);
    logical_t ( *AreOutputAndErrorSameTarget)(RexxIORedirectorContext *);
    logical_t ( *IsRedirectionRequested)(RexxIORedirectorContext *);
};
