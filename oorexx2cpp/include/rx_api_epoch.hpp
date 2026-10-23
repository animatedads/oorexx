// The interpreter epoch: a count that changes whenever the interpreter may have done anything compiled code cannot see.
// Architecture: Tom Dyer ("trigger on change", isChanged: cached objects passed while nothing changed). Coding: Claude.
//
// ooRexx has no change notification for its collections. Compiled code can still know when nothing has changed: while
// it runs it holds the interpreter's lock, so no Rexx code runs and no other thread touches an interpreter object until
// compiled code calls into the interpreter. Every such call goes through the thread context's function table
// (RexxThreadContext::functions). While compiled code runs, that table is replaced by a copy (installEpochTable, at each
// native entry: rxobj::Scope) whose functions bump the epoch before and after calling the interpreter's own, except
// the pure queries and constructors listed in RX_API_PURE, which cannot run Rexx code or change a collection. Entering
// and leaving compiled code bump it too (the interpreter ran in between). A cache keyed by the epoch is valid exactly
// while it has not moved: an environment symbol's value (rx::envValue), and whatever else needs "has the interpreter
// done anything since".
//
// Every function of the ooRexx 5 thread interface is in exactly one of the two lists below (checked against the
// header: the count of function pointers and THREAD_INTERFACE_VERSION). A function not known to be pure bumps.
#pragma once
#include <oorexxapi.h>
#include <atomic>
#include <type_traits>

namespace rxobj {
inline std::atomic<unsigned long> &interpreterEpochCounter() { static std::atomic<unsigned long> e{1}; return e; }
inline unsigned long interpreterEpoch() { return interpreterEpochCounter().load(std::memory_order_acquire); }
inline void interpreterChanged() { interpreterEpochCounter().fetch_add(1, std::memory_order_acq_rel); }

// Cannot run Rexx code, change a variable, or change a collection the interpreter could later answer from.
#define RX_API_PURE(X) \
    X(RequestGlobalReference) X(ReleaseGlobalReference) X(ReleaseLocalReference) X(GetLocalEnvironment) \
    X(GetGlobalEnvironment) X(IsInstanceOf) X(IsOfType) X(HasMethod) X(IsRoutine) X(IsMethod) X(WholeNumberToObject) \
    X(UintptrToObject) X(IntptrToObject) X(StringSizeToObject) X(Int64ToObject) X(UnsignedInt64ToObject) \
    X(Int32ToObject) X(UnsignedInt32ToObject) X(LogicalToObject) X(DoubleToObject) X(DoubleToObjectWithPrecision) \
    X(StringGet) X(StringLength) X(StringData) X(NewString) X(NewStringFromAsciiz) X(StringUpper) X(StringLower) \
    X(IsString) X(NewBufferString) X(BufferStringLength) X(BufferStringData) X(NewDirectory) \
    X(IsDirectory) X(ArrayAt) X(ArraySize) X(ArrayItems) X(ArrayDimension) X(NewArray) X(ArrayOfOne) X(ArrayOfTwo) \
    X(ArrayOfThree) X(ArrayOfFour) X(IsArray) X(BufferData) X(BufferLength) X(NewBuffer) X(IsBuffer) X(PointerValue) \
    X(NewPointer) X(IsPointer) X(IsStem) X(CheckCondition) X(IsMutableBuffer) X(MutableBufferData) \
    X(MutableBufferLength) X(MutableBufferCapacity) X(IsVariableReference) X(NewStringTable) \
    X(IsStringTable) X(GetInterpreterInstance) X(NewMutableBuffer) X(VariableReferenceName)
// Everything else: may run Rexx code (sends, calls, package loading, string and number conversions of objects; a
// Directory's get runs an entry's SETMETHOD method or its UNKNOWN method: DirectoryAt, StringTableAt),
// change a collection, a stem or a variable, let another thread run, or is not worth proving pure.
#define RX_API_BUMPS(X) \
    X(DetachThread) X(HaltThread) X(SetThreadTrace) X(SendMessage) X(SendMessage0) X(SendMessage1) X(SendMessage2) \
    X(LoadPackage) X(LoadPackageFromData) X(LoadLibrary) X(RegisterLibrary) X(FindClass) X(FindPackageClass) \
    X(GetPackageRoutines) X(GetPackagePublicRoutines) X(GetPackageClasses) X(GetPackagePublicClasses) \
    X(GetPackageMethods) X(CallRoutine) X(CallProgram) X(NewMethod) X(NewRoutine) X(GetRoutinePackage) \
    X(GetMethodPackage) X(ObjectToCSelf) X(ValueToObject) X(ValuesToObject) X(ObjectToValue) X(ObjectToWholeNumber) \
    X(ObjectToStringSize) X(ObjectToInt64) X(ObjectToUnsignedInt64) X(ObjectToInt32) X(ObjectToUnsignedInt32) \
    X(ObjectToUintptr) X(ObjectToIntptr) X(ObjectToLogical) X(ObjectToDouble) X(ObjectToString) X(ObjectToStringValue) \
    X(FinishBufferString) X(DirectoryAt) X(StringTableAt) X(DirectoryPut) X(DirectoryRemove) X(ArrayPut) X(ArrayAppend) X(ArrayAppendString) \
    X(SupplierItem) X(SupplierIndex) X(SupplierAvailable) X(SupplierNext) X(NewSupplier) X(NewStem) X(SetStemElement) \
    X(GetStemElement) X(DropStemElement) X(SetStemArrayElement) X(GetStemArrayElement) X(DropStemArrayElement) \
    X(GetAllStemElements) X(GetStemValue) X(RaiseException0) X(RaiseException1) X(RaiseException2) X(RaiseException) \
    X(RaiseCondition) X(GetConditionInfo) X(DecodeConditionInfo) X(ClearCondition) X(ObjectToCSelfScoped) \
    X(DisplayCondition) X(SetMutableBufferLength) X(SetMutableBufferCapacity) X(VariableReferenceValue) \
    X(SetVariableReferenceValue) X(StringTablePut) X(StringTableRemove) X(SendMessageScoped)

#define RX_API_COUNT_ONE(name) + 1
static_assert(THREAD_INTERFACE_VERSION == 103, "rx_api_epoch.hpp lists the ooRexx 5 thread interface (version 103)");
// (the interface version, the functions, then four objects: RexxNil, RexxTrue, RexxFalse, RexxNullString, copied as
// they are)
static_assert(sizeof(RexxThreadInterface) ==
                  sizeof(wholenumber_t) + (0 RX_API_PURE(RX_API_COUNT_ONE) RX_API_BUMPS(RX_API_COUNT_ONE) + 4) * sizeof(void *),
              "every thread interface function must be listed once in RX_API_PURE or RX_API_BUMPS");

inline const RexxThreadInterface *&interpreterApiTable() { static const RexxThreadInterface *t = nullptr; return t; }
template <auto Member, typename F> struct ApiBump;
template <auto Member, typename R, typename... A> struct ApiBump<Member, R (*)(A...)> {
    static R call(A... a) {
        interpreterChanged();
        if constexpr (std::is_void_v<R>) { (interpreterApiTable()->*Member)(a...); interpreterChanged(); }
        else { R r = (interpreterApiTable()->*Member)(a...); interpreterChanged(); return r; }
    }
};
// The interpreter's table with the bumping functions in place (one: the interpreter has one table for all threads).
inline RexxThreadInterface *epochTable(RexxThreadInterface *original) {
    static RexxThreadInterface table;
    static bool made = false;
    if (!made) {
        interpreterApiTable() = original;
        table = *original;
#define RX_API_WRAP(name) table.name = &ApiBump<&RexxThreadInterface::name, decltype(RexxThreadInterface::name)>::call;
        RX_API_BUMPS(RX_API_WRAP)
#undef RX_API_WRAP
        made = true;
    }
    return original == interpreterApiTable() ? &table : nullptr;
}
// At a native entry: the context uses the epoch table until the entry that installed it returns (restoreEpochTable).
// Answers the table it replaced (nullptr: already installed, or not the interpreter's table).
inline RexxThreadInterface *installEpochTable(RexxThreadContext *t) {
    if (!t || !t->functions) return nullptr;
    RexxThreadInterface *original = t->functions;
    if (interpreterApiTable() && original != interpreterApiTable()) return nullptr;   // ours already, or someone else's
    RexxThreadInterface *mine = epochTable(original);
    if (!mine) return nullptr;
    t->functions = mine;
    return original;
}
inline void restoreEpochTable(RexxThreadContext *t, RexxThreadInterface *original) {
    if (t && original) t->functions = original;
}
// A method context function that may let the interpreter run (ForwardMessage, SetGuardOn / SetGuardOff: the method
// context's own table, not the thread's): the epoch moves before and after it.
template <class F> inline auto viaInterpreter(F &&f) {
    interpreterChanged();
    struct After { ~After() { interpreterChanged(); } } after;
    return f();
}
}  // namespace rxobj
