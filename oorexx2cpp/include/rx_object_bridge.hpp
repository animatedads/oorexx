#pragma once
#include <cstdio>
// Real interpreter objects as rx::Value. One wrapper, two backends:
//  RX2CPP_KERNEL   : the interpreter compiled into the program (rx_kernel_bif.cpp)
//  RX2CPP_HOST_API : the interpreter that loaded this library (public oorexxapi.h, current thread context)
// Either way messages go to the interpreter's own dispatch and results are its own objects: no marshalling.
#if defined(RX2CPP_KERNEL) || defined(RX2CPP_HOST_API)
#include "minirexx_runtime.hpp"
#include <csignal>
#ifdef RX2CPP_KERNEL
#include "rx_kernel_bif.h"
namespace rxobj {
using Arg = rxkernel::Arg; using Result = rxkernel::Result;
inline void *findClass(const std::string &n) { return rxkernel::findClass(n); }
inline void release(void *h) { rxkernel::release(h); }
inline void *environmentObject(const std::string &) { return nullptr; }
inline void *environmentEntry(const std::string &) { return nullptr; }
inline void *selfHandle() { return nullptr; }   // the kernel backend has no receiver
inline void *nilObject() { return rxkernel::nil(); }
inline void *stringHandle(const std::string &) { throw std::runtime_error("interpreter String fallback is not available in kernel mode"); }
inline bool send(void *t, const std::string &s, const std::vector<Arg> &a, Result &r, std::string &c, std::string &x) {
    return rxkernel::send(t, s, a, r, c, x);
}
}
#else
#include <oorexxapi.h>
#include "rx_api_epoch.hpp"
#include <mutex>
#include <condition_variable>
#include <typeinfo>
#include <cstdlib>
#include <pwd.h>
#include <sys/time.h>
#include <ctime>
#include <unistd.h>
#include <map>
namespace rx { inline std::shared_ptr<ObjectDispatch> takeKeptCondition(); }
namespace rxobj {
// hold: a pin of obj for the life of the argument (a native instance's interpreter object, which nothing else in the
// interpreter references, must survive a collection during the send).
struct Arg { void *obj = nullptr; std::string bytes; bool omitted = false; std::shared_ptr<void> hold; };
struct Result { int kind = 0; std::string bytes; void *obj = nullptr; };
inline thread_local RexxThreadContext *current = nullptr;
inline thread_local RexxObjectPtr currentSelf = NULLOBJECT;
// The threads running compiled code. The library's cycle collector (native_package_template.cpp.in collectCycles)
// looks at every native object, so it runs only while the calling thread is the one thread in compiled code; a thread
// entering compiled code meanwhile waits for it to finish (exclusiveNative).
struct NativeGate { std::mutex m; std::condition_variable cv; int active = 0; bool collecting = false; };
inline NativeGate &nativeGate() { static NativeGate *g = new NativeGate; return *g; }   // never destroyed: used during exit
inline thread_local int nativeDepth = 0;
template <class F> inline bool exclusiveNative(F &&f) {
    NativeGate &g = nativeGate();
    {
        std::lock_guard<std::mutex> l(g.m);
        if (g.active != 1 || g.collecting || nativeDepth == 0) return false;
        g.collecting = true;
    }
    try { f(); } catch (...) {}
    { std::lock_guard<std::mutex> l(g.m); g.collecting = false; }
    g.cv.notify_all();
    return true;
}
inline void unpinRef(RexxThreadContext *t, void *h);
inline RexxObjectPtr pinRef(RexxThreadContext *t, RexxObjectPtr o);
// An interpreter object a native entry returns, that nothing else may reference (a native instance's own object, which
// compiled code does not pin): pinned until the next entry into compiled code, when the interpreter has it.
inline std::vector<void *> &returnPins() { static thread_local std::vector<void *> p; return p; }
inline void *returnPin(void *h);
// Set by every native method/routine entry for the duration of the call (self is NULLOBJECT in routines).
struct Scope {
    RexxThreadContext *previous; RexxObjectPtr previousSelf; Scope *outer;
    RexxThreadInterface *replaced = nullptr;   // the context's function table, while the epoch table is in place
    static Scope *&innermost() { static thread_local Scope *s = nullptr; return s; }
    explicit Scope(RexxThreadContext *c, RexxObjectPtr self = NULLOBJECT)
        : previous(current), previousSelf(currentSelf), outer(innermost()) {
        interpreterChanged();   // (the interpreter ran before this entry)
        replaced = installEpochTable(c);
        current = c; currentSelf = self; innermost() = this;
        if (!returnPins().empty()) for (void *h : std::exchange(returnPins(), std::vector<void *>())) unpinRef(c, h);
        if (nativeDepth++ == 0) {
            NativeGate &g = nativeGate();
            std::unique_lock<std::mutex> l(g.m);
            g.cv.wait(l, [&] { return !g.collecting; });
            ++g.active;
        }
    }
    ~Scope() {
        innermost() = outer;
        restoreEpochTable(current, replaced);
        interpreterChanged();   // (the interpreter runs after this entry returns)
        current = previous; currentSelf = previousSelf;
        if (--nativeDepth == 0) { NativeGate &g = nativeGate(); std::lock_guard<std::mutex> l(g.m); --g.active; }
    }
};
// Every object an API call returns stays referenced until the native method returns. A long-running compiled method makes
// millions of temporaries, so each is dropped as soon as it has been used.
struct LocalRefs {
    RexxThreadContext *t; std::vector<RexxObjectPtr> objs;
    explicit LocalRefs(RexxThreadContext *c) : t(c) {}
    RexxObjectPtr operator()(RexxObjectPtr o) { objs.push_back(o); return o; }
    ~LocalRefs() { for (RexxObjectPtr o : objs) if (o != NULLOBJECT) t->ReleaseLocalReference(o); }
};
// References kept by compiled code. ooRexx 5.3.0's ReleaseGlobalReference adds a global reference instead of removing one
// (InterpreterInstance::removeGlobalReference calls addGlobalReference), so an object once referenced from native code could
// never be collected (no UNINIT, a WeakReference never cleared, memory never returned). Compiled code keeps its references
// in an interpreter Array of its own instead (the pin table): one slot per object, counted here, emptied on the last release.
struct PinTable {
    std::mutex lock;
    RexxArrayObject array = NULLOBJECT;
    std::unordered_map<void *, std::pair<std::size_t, std::size_t>> slots;   // object -> (slot, count)
    std::vector<std::size_t> freeSlots;
    std::size_t nextSlot = 1;
};
inline PinTable &pinTable() { static PinTable *p = new PinTable; return *p; }   // never destroyed: used during exit
inline RexxObjectPtr pinRef(RexxThreadContext *t, RexxObjectPtr o) {
    if (o == NULLOBJECT) return o;
    PinTable &p = pinTable();
    std::lock_guard<std::mutex> g(p.lock);
    if (p.array == NULLOBJECT) {
        RexxArrayObject a = t->NewArray(1024);
        p.array = (RexxArrayObject)t->RequestGlobalReference((RexxObjectPtr)a);   // the table itself: kept for good
        t->ReleaseLocalReference((RexxObjectPtr)a);
    }
    auto it = p.slots.find((void *)o);
    if (it != p.slots.end()) { ++it->second.second; return o; }
    std::size_t slot;
    if (!p.freeSlots.empty()) { slot = p.freeSlots.back(); p.freeSlots.pop_back(); } else slot = p.nextSlot++;
    t->ArrayPut(p.array, o, slot);
    p.slots.emplace((void *)o, std::make_pair(slot, std::size_t(1)));
    return o;
}
// A pin dropped where no thread context is at hand (a destructor running outside a native call): released at the next
// pin or unpin that has one.
inline std::vector<void *> &deferredUnpins() { static std::vector<void *> *v = new std::vector<void *>; return *v; }
inline void unpinRef(RexxThreadContext *t, void *h);
inline void unpinLater(void *h) {
    if (!h) return;
    if (current) { unpinRef(current, h); return; }
    std::lock_guard<std::mutex> g(pinTable().lock);
    deferredUnpins().push_back(h);
}
inline void *returnPin(void *h) {
    if (h && current) returnPins().push_back((void *)pinRef(current, (RexxObjectPtr)h));
    return h;
}
inline void unpinRef(RexxThreadContext *t, void *h) {
    if (!h) return;
    PinTable &p = pinTable();
    std::lock_guard<std::mutex> g(p.lock);
    for (void *d : std::exchange(deferredUnpins(), std::vector<void *>())) {
        auto dt = p.slots.find(d);
        if (dt == p.slots.end() || --dt->second.second > 0) continue;
        t->ArrayPut(p.array, t->Nil(), dt->second.first);
        p.freeSlots.push_back(dt->second.first);
        p.slots.erase(dt);
    }
    auto it = p.slots.find(h);
    if (it == p.slots.end() || --it->second.second > 0) return;
    t->ArrayPut(p.array, t->Nil(), it->second.first);
    p.freeSlots.push_back(it->second.first);
    p.slots.erase(it);
}
inline void *selfHandle() {
    if (!current || currentSelf == NULLOBJECT) return nullptr;
    return (void *)rxobj::pinRef(current, currentSelf);
}
inline void *stringHandle(const std::string &bytes) {
    RexxThreadContext *t = current;
    if (!t) throw std::runtime_error("interpreter object used outside a native entry");
    RexxStringObject str = t->NewString(bytes.data(), bytes.size());
    void *h = (void *)rxobj::pinRef(t, (RexxObjectPtr)str);
    t->ReleaseLocalReference((RexxObjectPtr)str);
    return h;
}
inline void *nilObject() { return current ? (void *)current->Nil() : nullptr; }
inline RexxThreadContext *need() {
    if (!current) throw std::runtime_error("interpreter object used outside a native entry");
    return current;
}
inline RexxObjectPtr &libraryPackage();
inline void *findClass(const std::string &name) {
    RexxThreadContext *t = need();
    // the library's own package first (its classes that are not PUBLIC too), then the global search, as the interpreter
    // resolves a class name in the package that uses it
    RexxClassObject c = NULLOBJECT;
    if (libraryPackage() != NULLOBJECT) {
        c = t->FindPackageClass((RexxPackageObject)libraryPackage(), name.c_str());
        if (c == NULLOBJECT) t->ClearCondition();
        // (PackageClass::findClass goes on to .LOCAL and .ENVIRONMENT and answers any entry there: only a class is one,
        // as FindClass filters (NativeActivation::findClass); an entry such as a string is an environment entry)
        else {
            static thread_local RexxClassObject classClass = NULLOBJECT;
            if (classClass == NULLOBJECT) {
                classClass = t->FindClass("CLASS");
                if (classClass != NULLOBJECT) rxobj::pinRef(t, (RexxObjectPtr)classClass);
            }
            if (classClass != NULLOBJECT && !t->IsInstanceOf((RexxObjectPtr)c, classClass)) {
                t->ReleaseLocalReference((RexxObjectPtr)c);
                return nullptr;
            }
        }
    }
    if (c == NULLOBJECT) c = t->FindClass(name.c_str());
    if (c == NULLOBJECT) { t->ClearCondition(); return nullptr; }
    void *h = (void *)rxobj::pinRef(t, (RexxObjectPtr)c);
    t->ReleaseLocalReference((RexxObjectPtr)c);   // a long native call keeps every unreleased local reference
    return h;
}
// .LOCAL / .ENVIRONMENT are environment directories, not classes.
// The part of PackageClass::findClass whose answer the interpreter keeps for a .NAME (cachedValue): a class of the
// package (installed, installed public), one a required package made public (merged), or a public class of the REXX
// package. Asked of the collections the package answers (CLASSES, PUBLICCLASSES, IMPORTEDCLASSES): no environment
// directory is read (their entries, and a Directory's SETMETHOD entry or UNKNOWN method, are the dynamic part).
// The interpreter answers CLASSES / PUBLICCLASSES / IMPORTEDCLASSES with a copy (PackageClass::getClassesRexx), so they
// are asked once, when the library is loaded (takeFixedClassTables, after the packages it requires are imported), and
// looked up with StringTableAt afterwards: a lookup allocates nothing, as the interpreter's own findClass does not (the
// copies made at each first lookup moved what the interpreter's save stack still held: test_object_lifetime.sh).
struct FixedClassTables { RexxObjectPtr tables[4] = { NULLOBJECT, NULLOBJECT, NULLOBJECT, NULLOBJECT }; bool made = false; };
inline FixedClassTables &fixedClassTables() { static FixedClassTables f; return f; }
inline void takeFixedClassTables(RexxThreadContext *t) {
    FixedClassTables &f = fixedClassTables();
    LocalRefs temps(t);
    auto table = [&](RexxObjectPtr owner, const char *selector) -> RexxObjectPtr {
        if (owner == NULLOBJECT) return NULLOBJECT;
        RexxObjectPtr v = temps(t->SendMessage0(owner, selector));
        if (t->CheckCondition()) { t->ClearCondition(); return NULLOBJECT; }
        if (v == NULLOBJECT || v == t->Nil() || !t->IsStringTable(v)) return NULLOBJECT;
        return pinRef(t, v);
    };
    RexxObjectPtr pkg = libraryPackage();
    f.tables[0] = table(pkg, "CLASSES");
    f.tables[1] = table(pkg, "PUBLICCLASSES");
    f.tables[2] = table(pkg, "IMPORTEDCLASSES");
    RexxObjectPtr object = temps((RexxObjectPtr)t->FindClass("OBJECT"));
    RexxObjectPtr rexxPackage = object == NULLOBJECT ? NULLOBJECT : temps(t->SendMessage0(object, "PACKAGE"));
    if (t->CheckCondition()) { t->ClearCondition(); rexxPackage = NULLOBJECT; }
    if (rexxPackage != NULLOBJECT && rexxPackage != t->Nil()) f.tables[3] = table(rexxPackage, "PUBLICCLASSES");
    f.made = true;
}
inline void *packageClass(const std::string &name) {
    RexxThreadContext *t = need();
    FixedClassTables &f = fixedClassTables();
    if (!f.made) takeFixedClassTables(t);   // (a library loaded without the template's loader)
    for (RexxObjectPtr tab : f.tables) {
        if (tab == NULLOBJECT) continue;
        RexxObjectPtr c = t->StringTableAt((RexxStringTableObject)tab, name.c_str());
        if (c == NULLOBJECT) continue;
        void *h = (void *)pinRef(t, c);
        t->ReleaseLocalReference(c);
        return h;
    }
    return nullptr;
}
inline void *environmentObject(const std::string &name) {
    RexxThreadContext *t = need();
    RexxObjectPtr d = NULLOBJECT;
    if (rx::eqLit(name, "LOCAL")) d = (RexxObjectPtr)t->GetLocalEnvironment();
    else if (rx::eqLit(name, "ENVIRONMENT")) d = (RexxObjectPtr)t->GetGlobalEnvironment();
    if (d == NULLOBJECT) return nullptr;
    return (void *)rxobj::pinRef(t, d);
}
// The package that declares a native library's classes (set by its loader): .CONTEXT~PACKAGE, package-local symbols.
inline RexxObjectPtr &libraryPackage() { static RexxObjectPtr p = NULLOBJECT; return p; }
// A routine compiled code makes to run interpreter code for it (a helper) runs under the security manager of the
// compiled code's package, as that code would interpreted: RexxActivation takes its security manager from its code's
// package (settings.securityManager), so the helper's package is given the library package's (its PackageClass::
// securityManager field, packageFields). helperRoutine: kept and given it again before every call (CallRoutine, the
// epoch table: the library's manager may change); transientRoutine: used at once and dropped, given it now.
struct PackageFields { int securityManager = -1, manager = -1; bool known = false; };
inline std::unordered_map<void *, void *> &helperPackages() { static std::unordered_map<void *, void *> m; return m; }
inline PackageFields &packageFields(RexxThreadContext *t);
// The security manager (the interpreter's SecurityManager wrapper) compiled code runs under: its activation's, taken
// when it started (rx::ActivationScope::security), else the library package's now.
inline void *librarySecurity(RexxThreadContext *t) {
    if (libraryPackage() == NULLOBJECT) return nullptr;
    const PackageFields &f = packageFields(t);
    if (f.securityManager < 0) return nullptr;
    return reinterpret_cast<void *const *>(libraryPackage())[f.securityManager];
}
inline void *activationSecurity(RexxThreadContext *t) {
    if (rx::ActivationScope *s = rx::ActivationScope::current()) return s->security;
    return librarySecurity(t);
}
// (set while compiled code asks a security manager itself: that message is sent as is)
inline bool &securityCallInProgress() { static thread_local bool on = false; return on; }
inline void *securityAtActivationStart() { return current ? librarySecurity(current) : nullptr; }
inline const bool securityHookInstalled = (rx::ActivationScope::securityHook() = &securityAtActivationStart, true);
// The manager object of a SecurityManager wrapper (NULLOBJECT: none).
inline RexxObjectPtr securityManagerObject(RexxThreadContext *t, void *wrapper) {
    if (!wrapper) return NULLOBJECT;
    const PackageFields &f = packageFields(t);
    if (f.manager < 0) return NULLOBJECT;
    return (RexxObjectPtr)reinterpret_cast<void *const *>(wrapper)[f.manager];
}
inline void giveLibrarySecurity(RexxThreadContext *t, void *package) {
    if (!package || libraryPackage() == NULLOBJECT) return;
    const PackageFields &f = packageFields(t);
    if (f.securityManager < 0) return;
    void *const wanted = activationSecurity(t);
    void *&mine = reinterpret_cast<void **>(package)[f.securityManager];
    if (mine != wanted) mine = wanted;   // (OrefSet of an object made at run time: a plain store)
}
// The library's RX2CPP_CALLER_CONTEXT routine (NativeLibraryEmitter): a helper's own context, from ~CALL of it, without a
// .CONTEXT lookup (which a security manager is asked about, as for any environment symbol). NULLOBJECT: none.
inline RexxObjectPtr callerContextRoutine(RexxThreadContext *t) {
    static RexxObjectPtr routine = NULLOBJECT;
    static bool looked = false;
    if (looked) return routine;
    looked = true;
    if (libraryPackage() == NULLOBJECT) return routine;
    RexxDirectoryObject all = t->GetPackageRoutines((RexxPackageObject)libraryPackage());
    if (t->CheckCondition()) { t->ClearCondition(); return routine; }
    if (all == NULLOBJECT) return routine;
    RexxObjectPtr r = t->DirectoryAt(all, "RX2CPP_CALLER_CONTEXT");
    if (t->CheckCondition()) { t->ClearCondition(); return routine; }
    if (r != NULLOBJECT) routine = pinRef(t, r);
    return routine;
}
// A routine of the compiled code's own machinery (merging packages, the interpreter's version, a collection): no
// security manager, as the interpreter's own work has none.
inline RexxRoutineObject internalRoutine(RexxThreadContext *, RexxRoutineObject r) { return r; }
inline RexxRoutineObject transientRoutine(RexxThreadContext *t, RexxRoutineObject r) {
    if (r == NULLOBJECT) return r;
    RexxPackageObject p = t->GetRoutinePackage(r);
    giveLibrarySecurity(t, (void *)p);
    return r;
}
inline RexxRoutineObject helperRoutine(RexxThreadContext *t, RexxRoutineObject r) {
    if (r == NULLOBJECT) return r;
    RexxPackageObject p = t->GetRoutinePackage(r);
    helperPackages()[(void *)r] = (void *)p;
    giveLibrarySecurity(t, (void *)p);
    return r;
}
// (the epoch table's CallRoutine: a helper's package is given the library package's security manager first)
inline void beforeCallRoutine(RexxThreadContext *t, RexxRoutineObject r) {
    auto &m = helperPackages();
    if (m.empty()) return;
    auto it = m.find((void *)r);
    if (it != m.end()) giveLibrarySecurity(t, it->second);
}
inline const bool beforeCallRoutineInstalled = (callRoutineHook() = &beforeCallRoutine, true);
// An interpreter routine for compiled code to run: created in the library's declaration package when there is one, so
// it resolves names as the compiled code's own package would (public routines and classes of its ::REQUIRES, e.g. PP of
// ooTest.frm); otherwise a routine of its own.
inline RexxRoutineObject packageRoutine(RexxThreadContext *t, const char *name, const std::string &source) {
    if (libraryPackage() == NULLOBJECT) return rxobj::helperRoutine(t, t->NewRoutine(name, source.c_str(), source.size()));
    RexxObjectPtr routineClass = (RexxObjectPtr)t->FindClass("ROUTINE");
    RexxArrayObject lines = t->NewArray(0);
    std::size_t from = 0;
    while (from <= source.size()) {
        std::size_t nl = source.find('\n', from);
        if (nl == std::string::npos) nl = source.size();
        t->ArrayAppend(lines, (RexxObjectPtr)t->NewString(source.data() + from, nl - from));
        from = nl + 1;
    }
    RexxArrayObject args = t->ArrayOfThree((RexxObjectPtr)t->String(name), (RexxObjectPtr)lines, libraryPackage());
    RexxObjectPtr r = t->SendMessage(routineClass, "NEW", args);
    if (t->CheckCondition()) { t->ClearCondition(); return NULLOBJECT; }
    return helperRoutine(t, (RexxRoutineObject)r);
}
// An environment symbol that is not a class: the package's LOCAL directory, then .local, then .environment.
inline void *environmentEntry(const std::string &name) {
    RexxThreadContext *t = need();
    // Every local reference made here is released: inside one long native call they would pile up in its table.
    LocalRefs temps(t);
    RexxObjectPtr o = NULLOBJECT;
    if (libraryPackage() != NULLOBJECT) {
        RexxObjectPtr local = temps(t->SendMessage0(libraryPackage(), "LOCAL"));
        if (t->CheckCondition()) t->ClearCondition();
        else if (local != NULLOBJECT) o = temps(t->SendMessage1(local, "[]", temps((RexxObjectPtr)t->String(name.c_str()))));
        if (o == t->Nil()) o = NULLOBJECT;
    }
    if (o == NULLOBJECT) o = temps(t->DirectoryAt((RexxDirectoryObject)temps((RexxObjectPtr)t->GetLocalEnvironment()), name.c_str()));
    if (o == NULLOBJECT) o = temps(t->DirectoryAt((RexxDirectoryObject)temps((RexxObjectPtr)t->GetGlobalEnvironment()), name.c_str()));
    if (t->CheckCondition()) t->ClearCondition();
    if (o == NULLOBJECT) return nullptr;
    return (void *)rxobj::pinRef(t, o);
}
// environmentEntry's lookup without its per-call costs: the three directories (the package's LOCAL, .local,
// .environment) are found once per thread and kept; DirectoryAt is the interpreter's own get(), as
// PackageClass::findClass does. Answers a local reference (the caller releases it), or NULLOBJECT.
inline void bifStat(const std::string &name);
struct EnvDirs { RexxDirectoryObject pkg = NULLOBJECT, local = NULLOBJECT, global = NULLOBJECT; bool pkgDone = false; };
inline EnvDirs &envDirs() { static thread_local EnvDirs d; return d; }
// Does this Directory have SETMETHOD entries or an UNKNOWN method (DirectoryClass::methodTable, ::unknownMethod)? Its
// get() runs them, so a value read from it may be computed every time. The two fields are found once by comparing
// Directories made for the purpose (none, a SETMETHOD entry, an UNKNOWN method) and checked again after UNSETMETHOD of
// the UNKNOWN; when they cannot be found exactly the answer is always true (nothing is kept). A methodTable once made
// stays (empty) after UNSETMETHOD: still true, the safe side.
// An interpreter object's size in pointers (RexxInternalObject: its vtable, then ObjectHeader::objectSize in bytes);
// 0 when the size is not plausible. Bounds the scans below.
inline std::size_t objectWords(RexxObjectPtr o) {
    if (o == NULLOBJECT) return 0;
    const std::size_t bytes = reinterpret_cast<const std::size_t *>(o)[1];
    if (bytes < 4 * sizeof(void *) || bytes > 65536 || bytes % sizeof(void *) != 0) return 0;
    return bytes / sizeof(void *);
}
struct DirectoryFields { int methodTable = -1, unknownMethod = -1; bool known = false; };
inline DirectoryFields &directoryFields(RexxThreadContext *t) {
    static DirectoryFields f;
    if (f.known) return f;
    f.known = true;
    constexpr int words = 8;
    auto make = [&](const char *selector, const char *name) -> RexxObjectPtr {
        RexxObjectPtr d = (RexxObjectPtr)t->NewDirectory();
        if (d == NULLOBJECT) return NULLOBJECT;
        d = pinRef(t, d);
        if (selector) {
            RexxObjectPtr src = (RexxObjectPtr)t->String("return 1");
            t->SendMessage2(d, selector, (RexxObjectPtr)t->String(name), src);
            if (t->CheckCondition()) { t->ClearCondition(); return NULLOBJECT; }
        }
        return d;
    };
    RexxObjectPtr none1 = make(nullptr, nullptr), none2 = make(nullptr, nullptr);
    RexxObjectPtr method1 = make("SETMETHOD", "X"), method2 = make("SETMETHOD", "Y");
    RexxObjectPtr unknown1 = make("SETMETHOD", "UNKNOWN"), unknown2 = make("SETMETHOD", "UNKNOWN");
    if (!none1 || !none2 || !method1 || !method2 || !unknown1 || !unknown2) return f;
    auto word = [](RexxObjectPtr o, int i) { return reinterpret_cast<void *const *>(o)[i]; };
    int mt = -1, um = -1, mtCount = 0, umCount = 0;
    const int size = static_cast<int>(std::min({objectWords(none1), objectWords(method1), objectWords(unknown1)}));
    for (int i = 3; i < words && i < size; ++i) {
        const bool noneZero = !word(none1, i) && !word(none2, i);
        if (noneZero && word(method1, i) && word(method2, i) && !word(unknown1, i) && !word(unknown2, i)) { mt = i; ++mtCount; }
        if (noneZero && !word(method1, i) && !word(method2, i) && word(unknown1, i) && word(unknown2, i)) { um = i; ++umCount; }
    }
    if (mtCount != 1 || umCount != 1 || um != mt + 1) { bifStat("directory fields not found"); return f; }   // (declared one after the other)
    t->SendMessage1(unknown1, "UNSETMETHOD", (RexxObjectPtr)t->String("UNKNOWN"));
    if (t->CheckCondition()) { t->ClearCondition(); return f; }
    if (word(unknown1, um)) return f;
    f.methodTable = mt; f.unknownMethod = um;
    bifStat("directory fields " + std::to_string(mt) + "/" + std::to_string(um));
    return f;
}
// Would DirectoryClass::get of NAME from this Directory run code? get() answers an entry of its contents first; only
// when there is none does it run a SETMETHOD entry of that name (methodTable), then the UNKNOWN method. So a NAME is
// computed when the Directory has an UNKNOWN method, or a SETMETHOD entry of that very name. (.environment always has
// one SETMETHOD entry, LOCAL: the interpreter's own ActivityManager::getLocalRexx, Setup.cpp; only .LOCAL is computed.)
// StringTableAt is the method table's own get: no Rexx code. Fields not found: always computed (nothing is kept).
inline bool directoryComputes(RexxThreadContext *t, RexxDirectoryObject d, const char *name) {
    if (d == NULLOBJECT) return false;
    const DirectoryFields &f = directoryFields(t);
    if (f.methodTable < 0) return true;
    auto word = [&](int i) { return reinterpret_cast<void *const *>(d)[i]; };
    if (word(f.unknownMethod) != nullptr) return true;
    void *methods = word(f.methodTable);
    if (methods == nullptr) return false;
    RexxObjectPtr m = t->StringTableAt((RexxStringTableObject)methods, name);
    if (m == NULLOBJECT) return false;
    t->ReleaseLocalReference(m);
    return true;
}
// The three directories of an environment symbol answer NAME from their own entries (no SETMETHOD entry of that name,
// no UNKNOWN method): a value found there stays the same while the interpreter epoch does not move.
inline EnvDirs &findEnvDirs(RexxThreadContext *t);
inline bool environmentEntriesOnly(RexxThreadContext *t, const std::string &name) {
    EnvDirs &d = findEnvDirs(t);
    return !directoryComputes(t, d.pkg, name.c_str()) && !directoryComputes(t, d.local, name.c_str()) &&
           !directoryComputes(t, d.global, name.c_str());
}
inline EnvDirs &findEnvDirs(RexxThreadContext *t) {
    EnvDirs &d = envDirs();
    if (!d.pkgDone && libraryPackage() != NULLOBJECT) {
        d.pkgDone = true;
        RexxObjectPtr l = t->SendMessage0(libraryPackage(), "LOCAL");
        if (t->CheckCondition()) t->ClearCondition();
        else if (l != NULLOBJECT && l != t->Nil() && t->IsDirectory(l)) d.pkg = (RexxDirectoryObject)pinRef(t, l);
        if (l != NULLOBJECT) t->ReleaseLocalReference(l);
    }
    if (d.local == NULLOBJECT) {
        RexxObjectPtr l = (RexxObjectPtr)t->GetLocalEnvironment();
        d.local = (RexxDirectoryObject)pinRef(t, l); t->ReleaseLocalReference(l);
        RexxObjectPtr g = (RexxObjectPtr)t->GetGlobalEnvironment();
        d.global = (RexxDirectoryObject)pinRef(t, g); t->ReleaseLocalReference(g);
    }
    return d;
}
// The package's security manager (PackageClass::securityManager, a SecurityManager whose ::manager is the object set by
// SETSECURITYMANAGER): PackageClass::findClass asks it (LOCAL, ENVIRONMENT) before .local and .environment. The two
// fields are found once: in a package given a security manager (an object made for the purpose) the one pointer
// that is empty in a package without one, and in the object it points to, the manager itself.
inline PackageFields &packageFields(RexxThreadContext *t) {
    static PackageFields f;
    if (f.known) return f;
    f.known = true;
    RexxObjectPtr packageClass = (RexxObjectPtr)t->FindClass("PACKAGE"), objectClass = (RexxObjectPtr)t->FindClass("OBJECT");
    if (packageClass == NULLOBJECT || objectClass == NULLOBJECT) { t->ClearCondition(); return f; }
    auto make = [&](const char *name) -> RexxObjectPtr {
        RexxObjectPtr p = t->SendMessage2(packageClass, "NEW", (RexxObjectPtr)t->String(name), (RexxObjectPtr)t->String("nop"));
        if (t->CheckCondition()) { t->ClearCondition(); return NULLOBJECT; }
        return p == NULLOBJECT ? NULLOBJECT : pinRef(t, p);
    };
    RexxObjectPtr plain1 = make("RX2CPP_PROBE_1"), plain2 = make("RX2CPP_PROBE_2"), managed = make("RX2CPP_PROBE_3");
    RexxObjectPtr m = t->SendMessage0(objectClass, "NEW");
    if (!plain1 || !plain2 || !managed || m == NULLOBJECT || t->CheckCondition()) { t->ClearCondition(); return f; }
    m = pinRef(t, m);
    t->SendMessage1(managed, "SETSECURITYMANAGER", m);
    if (t->CheckCondition()) { t->ClearCondition(); return f; }
    auto word = [](RexxObjectPtr o, std::size_t i) { return reinterpret_cast<void *const *>(o)[i]; };
    const std::size_t size = std::min({objectWords(plain1), objectWords(plain2), objectWords(managed)});
    int sm = -1, mg = -1, found = 0;
    for (std::size_t i = 3; i < size; ++i) {
        if (word(plain1, i) || word(plain2, i) || !word(managed, i)) continue;
        RexxObjectPtr wrapper = (RexxObjectPtr)word(managed, i);
        const std::size_t wsize = objectWords(wrapper);
        for (std::size_t j = 3; j < wsize; ++j)
            if (word(wrapper, j) == (void *)m) { sm = static_cast<int>(i); mg = static_cast<int>(j); ++found; }
    }
    if (found != 1) { bifStat("security manager fields not found"); return f; }
    f.securityManager = sm; f.manager = mg;
    bifStat("security manager fields " + std::to_string(sm) + "/" + std::to_string(mg));
    return f;
}
// The security manager of a package: 0 none, 1 one (its manager object in m), -1 not known (its fields were not found).
inline int packageSecurityManager(RexxThreadContext *t, RexxObjectPtr package, RexxObjectPtr &m) {
    m = NULLOBJECT;
    if (package == NULLOBJECT) return 0;
    const PackageFields &f = packageFields(t);
    if (f.securityManager < 0) return -1;
    void *wrapper = reinterpret_cast<void *const *>(package)[f.securityManager];
    if (!wrapper) return 0;
    m = (RexxObjectPtr)reinterpret_cast<void *const *>(wrapper)[f.manager];
    return 1;
}
inline RexxObjectPtr environmentLookup(RexxThreadContext *t, const std::string &name) {
    EnvDirs &d = findEnvDirs(t);
    // (a condition raised by a SETMETHOD entry or an UNKNOWN method stays pending for the caller: rx::envValue raises it)
    RexxObjectPtr o = NULLOBJECT;
    if (d.pkg != NULLOBJECT) o = t->DirectoryAt(d.pkg, name.c_str());
    if (t->CheckCondition()) return NULLOBJECT;
    if (o == NULLOBJECT && d.local != NULLOBJECT) o = t->DirectoryAt(d.local, name.c_str());
    if (t->CheckCondition()) return NULLOBJECT;
    if (o == NULLOBJECT && d.global != NULLOBJECT) o = t->DirectoryAt(d.global, name.c_str());
    if (t->CheckCondition()) { if (o != NULLOBJECT) t->ReleaseLocalReference(o); return NULLOBJECT; }
    return o;
}
// Does this object run Object's own == and \== (identity, RexxObject::strictEqual)? Asked of the object's behaviour
// (INSTANCEMETHOD), compared with .Object's methods; false when unsure.
inline bool objectIdentityEquality(void *h) {
    RexxThreadContext *t = need();
    LocalRefs temps(t);
    static thread_local RexxObjectPtr eq = NULLOBJECT, ne = NULLOBJECT;
    auto method = [&](RexxObjectPtr target, const char *selector, const char *name) -> RexxObjectPtr {
        RexxObjectPtr m = temps(t->SendMessage1(target, selector, temps((RexxObjectPtr)t->String(name))));
        if (t->CheckCondition()) { t->ClearCondition(); return NULLOBJECT; }
        return m;
    };
    if (eq == NULLOBJECT) {
        RexxObjectPtr object = temps((RexxObjectPtr)t->FindClass("OBJECT"));
        RexxObjectPtr e = method(object, "METHOD", "=="), n = method(object, "METHOD", "\\==");
        if (e == NULLOBJECT || n == NULLOBJECT) return false;
        eq = pinRef(t, e); ne = pinRef(t, n);
    }
    RexxObjectPtr e = method((RexxObjectPtr)h, "INSTANCEMETHOD", "=="), n = method((RexxObjectPtr)h, "INSTANCEMETHOD", "\\==");
    return e != NULLOBJECT && e == eq && n != NULLOBJECT && n == ne;
}
// RX2CPP_REF_STATS=1: global references taken by sends, released, and dropped without a context (leaked); printed at exit.
struct RefStats {
    std::atomic<unsigned long> taken{0}, released{0}, dropped{0};
    bool on = std::getenv("RX2CPP_REF_STATS") != nullptr;
    ~RefStats() { if (on) std::fprintf(stderr, "rx2cpp refs: taken %lu released %lu dropped %lu\n", taken.load(), released.load(), dropped.load()); }
};
inline RefStats &refStats() { static RefStats s; return s; }
inline void release(void *h) {
    if (!h) return;
    if (current) { unpinRef(current, h); if (refStats().on) ++refStats().released; }
    else if (refStats().on) ++refStats().dropped;
}
// A value that crosses as a plain string: a .String (or the interpreter's internal integer/number forms of it). An instance of
// a String SUBCLASS (json.cls JsonString, ...) is an object and keeps its class.
inline bool isPlainString(RexxThreadContext *t, RexxObjectPtr o) {
    if (t->IsString(o)) return true;
    static thread_local RexxObjectPtr stringClass = NULLOBJECT;
    if (stringClass == NULLOBJECT) stringClass = rxobj::pinRef(t, (RexxObjectPtr)t->FindClass("STRING"));
    // Instance test against the cached class object, not a by-name class lookup per result.
    if (!t->IsInstanceOf(o, (RexxClassObject)stringClass)) return false;
    RexxObjectPtr cls = t->SendMessage0(o, "CLASS");
    if (t->CheckCondition()) { t->ClearCondition(); return true; }
    if (cls != NULLOBJECT) t->ReleaseLocalReference(cls);
    return cls == stringClass;
}
// The substitution values (ADDITIONAL) of the last interpreter condition a send turned into a C++ exception, so the
// condition can be raised again unchanged when it leaves compiled code.
inline std::vector<std::string> &lastAdditional() { static thread_local std::vector<std::string> v; return v; }
// The interpreter's condition object (a global reference) of the last condition the bridge cleared to throw it in C++;
// the thrower attaches it to the exception (takeKeptCondition), so a compiled SIGNAL ON trap sees the real object.
inline void *&keptCondition() { static thread_local void *h = nullptr; return h; }
inline void keepCondition(RexxThreadContext *t) {
    if (keptCondition()) { unpinRef(t, keptCondition()); keptCondition() = nullptr; }
    RexxDirectoryObject info = t->GetConditionInfo();
    if (info != NULLOBJECT) keptCondition() = (void *)rxobj::pinRef(t, (RexxObjectPtr)info);
}
inline void captureAdditional(RexxThreadContext *t, RexxDirectoryObject info) {
    lastAdditional().clear();
    if (info == NULLOBJECT) return;
    RexxObjectPtr add = t->DirectoryAt(info, "ADDITIONAL");
    if (add == NULLOBJECT || !t->IsArray(add)) return;
    const size_t n = t->ArraySize((RexxArrayObject)add);
    for (size_t i = 1; i <= n; ++i) {
        RexxObjectPtr o = t->ArrayAt((RexxArrayObject)add, i);
        if (o == NULLOBJECT) { lastAdditional().push_back(std::string()); continue; }
        // An explicit ~STRING: the API's implicit conversion would raise NOSTRING when the caller traps ANY.
        RexxObjectPtr s = t->IsString(o) ? o : t->SendMessage0(o, "STRING");
        if (t->CheckCondition()) { t->ClearCondition(); s = NULLOBJECT; }
        lastAdditional().push_back(s == NULLOBJECT || !t->IsString(s) ? std::string() : std::string(t->ObjectToStringValue(s)));
    }
}
// A new interpreter Array of `size` slots holding `items` (items[i] at index i+1; an omitted Arg leaves a hole).
inline void *newArray(std::size_t size, const std::vector<Arg> &items) {
    RexxThreadContext *t = need();
    LocalRefs temps(t);
    RexxArrayObject arr = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(size));
    for (std::size_t i = 0; i < items.size(); i++) {
        const Arg &a = items[i];
        if (a.omitted) continue;
        t->ArrayPut(arr, a.obj ? (RexxObjectPtr)a.obj : temps((RexxObjectPtr)t->NewString(a.bytes.data(), a.bytes.size())), i + 1);
    }
    return (void *)rxobj::pinRef(t, (RexxObjectPtr)arr);
}
// Store entries into an interpreter Directory in the given order (the same as [] = for each, without a send per entry).
inline void directoryPutAll(void *dir, const std::vector<std::string> &keys, const std::vector<Arg> &values, bool directory = true) {
    RexxThreadContext *t = need();
    for (std::size_t i = 0; i < keys.size(); i++) {
        LocalRefs temps(t);
        const Arg &a = values[i];
        RexxObjectPtr value = a.obj ? (RexxObjectPtr)a.obj : temps((RexxObjectPtr)t->NewString(a.bytes.data(), a.bytes.size()));
        // (DirectoryPut is the Directory API; a StringTable takes []=, the same put)
        if (directory && keys[i].find('\0') == std::string::npos) t->DirectoryPut((RexxDirectoryObject)dir, value, keys[i].c_str());
        else temps(t->SendMessage2((RexxObjectPtr)dir, "[]=", value, temps((RexxObjectPtr)t->NewString(keys[i].data(), keys[i].size()))));
    }
}
// The interpreter's condition object for SYNTAX `code` with these substitutions, made by the interpreter itself (a tiny
// routine that RAISEs it under SIGNAL ON SYNTAX): CODE, RC, MESSAGE, ERRORTEXT, ADDITIONAL, DESCRIPTION are exact.
inline void *conditionObject(const std::string &code, const std::vector<Arg> &subs) {
    RexxThreadContext *t = need();
    static thread_local RexxObjectPtr routine = NULLOBJECT;
    if (routine == NULLOBJECT) {
        static const char source[] =
            "use arg code, subs\n"
            "signal on syntax\n"
            "if subs~items = 0 then raise syntax (code)\n"
            "raise syntax (code) additional (subs)\n"
            "syntax: return condition('O')\n";
        RexxRoutineObject made = rxobj::internalRoutine(t, t->NewRoutine("rx2cpp_condition", source, sizeof(source) - 1));
        if (made == NULLOBJECT || t->CheckCondition()) { t->ClearCondition(); throw std::runtime_error("cannot build a condition object"); }
        routine = rxobj::pinRef(t, (RexxObjectPtr)made);
    }
    LocalRefs temps(t);
    RexxArrayObject array = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(subs.size()));
    for (std::size_t i = 0; i < subs.size(); i++)
        t->ArrayPut(array, subs[i].obj ? (RexxObjectPtr)subs[i].obj : temps((RexxObjectPtr)t->NewString(subs[i].bytes.data(), subs[i].bytes.size())), i + 1);
    RexxArrayObject args = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(2));
    t->ArrayPut(args, temps((RexxObjectPtr)t->NewString(code.data(), code.size())), 1);
    t->ArrayPut(args, (RexxObjectPtr)array, 2);
    RexxObjectPtr r = temps(t->CallRoutine((RexxRoutineObject)routine, args));
    if (t->CheckCondition() || r == NULLOBJECT) { t->ClearCondition(); throw std::runtime_error("cannot build a condition object for " + code); }
    return (void *)rxobj::pinRef(t, r);
}
// PARSE VERSION of the interpreter running this library (asked once).
inline std::string interpreterVersion() {
    static std::string version;
    static std::once_flag once;
    std::call_once(once, [] {
        RexxThreadContext *t = need();
        static const char source[] = "parse version v\nreturn v\n";
        RexxRoutineObject r = rxobj::internalRoutine(t, t->NewRoutine("rx2cpp_version", source, sizeof(source) - 1));
        RexxObjectPtr v = r == NULLOBJECT ? NULLOBJECT : t->CallRoutine(r, t->NewArray(0));
        if (t->CheckCondition() || v == NULLOBJECT) { t->ClearCondition(); throw std::runtime_error("cannot read PARSE VERSION"); }
        version = t->ObjectToStringValue(v);
    });
    return version;
}
inline void bifStat(const std::string &name);
// RX2CPP_BIF_STATS: a native instance whose interpreter object was just made to be an argument (named with the send it
// goes to)
inline thread_local std::string pendingArgumentStat;
inline bool send(void *target, const std::string &selector, const std::vector<Arg> &args, Result &out,
                 std::string &code, std::string &text) {
    RexxThreadContext *t = need();
    static const bool sendStats = std::getenv("RX2CPP_BIF_STATS") != nullptr;
    if (sendStats) {
        std::string cls = t->ObjectToStringValue(t->SendMessage0((RexxObjectPtr)target, "CLASS"));
        // A class object: name the class itself (.Directory~new, .MathInteger~coerce, ...).
        if (cls == "The Class class") cls = std::string("class ") + t->ObjectToStringValue(t->SendMessage0((RexxObjectPtr)target, "ID"));
        bifStat("~" + selector + " to " + cls);
        if (!pendingArgumentStat.empty()) { bifStat(pendingArgumentStat + " to ~" + selector + " to " + cls); pendingArgumentStat.clear(); }
        // RX2CPP_TRAP_SEND="~NEW to class X": stop in the debugger at that send (where does it come from?).
        static const char *trap = std::getenv("RX2CPP_TRAP_SEND");
        if (trap && ("~" + selector + " to " + cls) == trap) std::raise(SIGTRAP);
    }
    LocalRefs temps(t);
    auto argObj = [&](const Arg &a) -> RexxObjectPtr {
        return a.obj ? (RexxObjectPtr)a.obj : temps((RexxObjectPtr)t->NewString(a.bytes.data(), a.bytes.size()));
    };
    bool holes = false;
    for (const Arg &a : args) holes = holes || a.omitted;
    RexxObjectPtr r;
    // routine~CALL / ~CALLWITH: sent from a small interpreted routine. The interpreter takes the frame that calls a native
    // routine for a Rexx activation (NativeActivation::callNativeRoutine, accessCallerContext): sent from compiled code,
    // that frame would be this method's native activation, and an error in the routine (reraiseException) or its
    // caller's context (digits, ...) would read it as one (a crash: compiled Rexx Parser, Clauses.cls).
    static const auto isRoutineCall = [](const std::string &sel) {
        if (sel.size() != 4 && sel.size() != 8) return false;
        std::string u(sel);
        for (char &c : u) c = (char)std::toupper((unsigned char)c);
        return u == "CALL" || u == "CALLWITH";
    };
    RexxObjectPtr viaHelper = NULLOBJECT;
    if (isRoutineCall(selector)) {
        static RexxClassObject routineClass = NULLOBJECT;
        if (routineClass == NULLOBJECT) {
            routineClass = t->FindClass("ROUTINE");
            if (routineClass != NULLOBJECT) rxobj::pinRef(t, (RexxObjectPtr)routineClass);
        }
        if (routineClass != NULLOBJECT && t->IsInstanceOf((RexxObjectPtr)target, routineClass)) {
            static RexxRoutineObject helper = NULLOBJECT;
            if (helper == NULLOBJECT) {
                static const char source[] = "use arg rx2cppR, rx2cppM, rx2cppA\nrx2cppR~sendWith(rx2cppM, rx2cppA)\n"
                                             "if var('RESULT') then return result\nreturn\n";
                helper = rxobj::helperRoutine(t, t->NewRoutine("rx2cpp_routine_call", source, sizeof(source) - 1));
                if (helper != NULLOBJECT) rxobj::pinRef(t, (RexxObjectPtr)helper);
                else t->ClearCondition();
            }
            if (helper != NULLOBJECT) {
                RexxArrayObject arr = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(args.size()));
                for (std::size_t i = 0; i < args.size(); i++)
                    if (!args[i].omitted) t->ArrayPut(arr, argObj(args[i]), i + 1);
                RexxArrayObject call = (RexxArrayObject)temps((RexxObjectPtr)t->ArrayOfThree((RexxObjectPtr)target,
                    temps((RexxObjectPtr)t->String(selector.c_str())), (RexxObjectPtr)arr));
                viaHelper = helper;
                r = temps(t->CallRoutine(helper, call));
            }
        }
    }
    // Under a security manager (the activation's: activationSecurity) the message is sent from a helper that runs under
    // it: the interpreter asks the sender's manager about a PROTECTED method (RexxObject::processProtectedMethod, the
    // top frame's: a helper activation takes its package's), as it would of this code interpreted.
    if (viaHelper == NULLOBJECT && !securityCallInProgress() && securityManagerObject(t, activationSecurity(t)) != NULLOBJECT) {
        static RexxRoutineObject secured = NULLOBJECT;
        if (secured == NULLOBJECT) {
            static const char source[] = "use arg rx2cppO, rx2cppM, rx2cppA\nrx2cppO~sendWith(rx2cppM, rx2cppA)\n"
                                         "if var('RESULT') then return result\nreturn\n";
            secured = helperRoutine(t, t->NewRoutine("rx2cpp_secured_send", source, sizeof(source) - 1));
            if (secured != NULLOBJECT) rxobj::pinRef(t, (RexxObjectPtr)secured);
            else t->ClearCondition();
        }
        if (secured != NULLOBJECT) {
            RexxArrayObject arr = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(args.size()));
            for (std::size_t i = 0; i < args.size(); i++)
                if (!args[i].omitted) t->ArrayPut(arr, argObj(args[i]), i + 1);
            RexxArrayObject call = (RexxArrayObject)temps((RexxObjectPtr)t->ArrayOfThree((RexxObjectPtr)target,
                temps((RexxObjectPtr)t->String(selector.c_str())), (RexxObjectPtr)arr));
            viaHelper = secured;
            r = temps(t->CallRoutine(secured, call));
        }
    }
    // Up to two arguments and no omitted ones: no argument array is built.
    if (viaHelper != NULLOBJECT) {}
    else if (!holes && args.empty()) r = temps(t->SendMessage0((RexxObjectPtr)target, selector.c_str()));
    else if (!holes && args.size() == 1) r = temps(t->SendMessage1((RexxObjectPtr)target, selector.c_str(), argObj(args[0])));
    else if (!holes && args.size() == 2) {
        RexxObjectPtr a1 = argObj(args[0]), a2 = argObj(args[1]);
        r = temps(t->SendMessage2((RexxObjectPtr)target, selector.c_str(), a1, a2));
    } else {
        RexxArrayObject arr = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(args.size()));
        // Omitted arguments stay holes at their positions (an array hole is an omitted ARG).
        for (std::size_t i = 0; i < args.size(); i++) {
            const Arg &a = args[i];
            if (a.omitted) continue;
            t->ArrayPut(arr, argObj(a), i + 1);
        }
        r = temps(t->SendMessage((RexxObjectPtr)target, selector.c_str(), arr));
    }
    if (t->CheckCondition()) {
        RexxDirectoryObject info = t->GetConditionInfo();
        RexxCondition cd; t->DecodeConditionInfo(info, &cd);
        code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        text = (cd.message && t->IsString(cd.message)) ? t->ObjectToStringValue(cd.message) : "error in message " + selector;
        keepCondition(t);          // the condition object itself, before anything else runs in the interpreter
        t->ClearCondition();
        captureAdditional(t, info);   // sends ~STRING: only with no condition pending
        return false;
    }
    if (r == NULLOBJECT) { out.kind = 0; return true; }
    if (isPlainString(t, r)) {
        RexxStringObject str = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(r));
        out.kind = 1; out.bytes.assign(t->StringData(str), t->StringLength(str));
    } else { out.kind = 2; out.obj = (void *)rxobj::pinRef(t, r); if (refStats().on) ++refStats().taken; }
    return true;
}
// RX2CPP_BIF_STATS=1: count the BIFs/String methods that went to the interpreter (printed at exit): the next native candidates.
inline void bifStat(const std::string &name) {
    static const bool stats = std::getenv("RX2CPP_BIF_STATS") != nullptr;
    if (!stats) return;
    static std::mutex m;
    static std::map<std::string, std::size_t> counts;
    std::lock_guard<std::mutex> g(m);
    static const bool registered = (std::atexit([] { for (auto &c : counts) std::fprintf(stderr, "rx2cpp via interpreter: %s %zu\n", c.first.c_str(), c.second); }), true);
    (void)registered;
    ++counts[name];
}
// Delegated BIFs run in the host interpreter: a tiny routine per (name, omission pattern, NUMERIC settings), cached.
// receiver~selector(args) for a String receiver, executed under the caller's NUMERIC settings (omitted arguments stay omitted).
inline bool sendStringNumeric(const std::string &receiver, const std::string &selector, const std::vector<Arg> &args,
                              std::size_t digits, std::size_t fuzz, bool engineering, Result &out,
                              std::string &code, std::string &text) {
    RexxThreadContext *t = need();
    LocalRefs temps(t);
    static thread_local std::unordered_map<std::string, RexxRoutineObject> cache;
    std::string source = "numeric digits " + std::to_string(digits) + "; numeric fuzz " + std::to_string(fuzz) +
                         "; numeric form " + (engineering ? "engineering" : "scientific") + "; return arg(1)~" + selector + "(";
    for (std::size_t i = 0; i < args.size(); i++) {
        if (i) source += ",";
        if (!args[i].omitted) source += "arg(" + std::to_string(i + 2) + ")";
    }
    source += ")";
    RexxRoutineObject routine;
    auto it = cache.find(source);
    if (it == cache.end()) {
        routine = rxobj::helperRoutine(t, t->NewRoutine("rx2cpp_msg", source.c_str(), source.size()));
        if (routine == NULLOBJECT) { code = "98.900"; text = "cannot create message routine for " + selector; t->ClearCondition(); return false; }
        rxobj::pinRef(t, (RexxObjectPtr)routine);
        cache.emplace(source, routine);
    } else routine = it->second;
    RexxArrayObject arr = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(args.size() + 1));
    t->ArrayPut(arr, temps((RexxObjectPtr)t->NewString(receiver.data(), receiver.size())), 1);
    for (std::size_t i = 0; i < args.size(); i++) {
        if (args[i].omitted) continue;
        t->ArrayPut(arr, args[i].obj ? (RexxObjectPtr)args[i].obj : temps((RexxObjectPtr)t->NewString(args[i].bytes.data(), args[i].bytes.size())), i + 2);
    }
    RexxObjectPtr r = temps(t->CallRoutine(routine, arr));
    if (t->CheckCondition()) {
        RexxCondition cd; t->DecodeConditionInfo(t->GetConditionInfo(), &cd);
        code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        text = (cd.message && t->IsString(cd.message)) ? t->ObjectToStringValue(cd.message) : "error in message " + selector;
        keepCondition(t);
        t->ClearCondition();
        return false;
    }
    if (r == NULLOBJECT) { out.kind = 0; return true; }
    if (isPlainString(t, r)) {
        RexxStringObject str = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(r));
        out.kind = 1; out.bytes.assign(t->StringData(str), t->StringLength(str));
    } else { out.kind = 2; out.obj = (void *)rxobj::pinRef(t, r); if (refStats().on) ++refStats().taken; }
    return true;
}
inline std::string callBif(const std::string &name, const std::vector<std::pair<bool, std::string>> &args,
                           std::size_t digits, std::size_t fuzz, bool engineering, const std::string &directives = std::string()) {
    RexxThreadContext *t = need();
    LocalRefs temps(t);
    bifStat(name);
    static thread_local std::unordered_map<std::string, RexxRoutineObject> cache;
    std::string source = "numeric digits " + std::to_string(digits) + "; numeric fuzz " + std::to_string(fuzz) +
                         "; numeric form " + (engineering ? "engineering" : "scientific") + "; return " + name + "(";
    for (std::size_t i = 0; i < args.size(); i++) {
        if (i) source += ",";
        if (args[i].first) source += "arg(" + std::to_string(i + 1) + ")";
    }
    source += ")";
    if (!directives.empty()) source += "\n" + directives + "\n";
    auto it = cache.find(source);
    RexxRoutineObject routine;
    if (it == cache.end()) {
        routine = rxobj::helperRoutine(t, t->NewRoutine("rx2cpp_bif", source.c_str(), source.size()));
        if (routine == NULLOBJECT) throw std::runtime_error("cannot create BIF routine for " + name);
        rxobj::pinRef(t, (RexxObjectPtr)routine);
        cache.emplace(source, routine);
    } else routine = it->second;
    RexxArrayObject arr = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(args.size()));
    for (const auto &a : args) {
        if (a.first) t->ArrayAppend(arr, temps((RexxObjectPtr)t->NewString(a.second.data(), a.second.size())));
        else t->ArrayAppend(arr, (RexxObjectPtr)t->Nil());
    }
    RexxObjectPtr r = temps(t->CallRoutine(routine, arr));
    if (t->CheckCondition()) {
        RexxCondition cd; t->DecodeConditionInfo(t->GetConditionInfo(), &cd);
        std::string code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        std::string text = (cd.message && t->IsString(cd.message)) ? t->ObjectToStringValue(cd.message) : "error in " + name;
        RexxDirectoryObject info = t->GetConditionInfo();
        keepCondition(t);
        t->ClearCondition();
        captureAdditional(t, info);   // the message substitutions, no condition pending
        rx::SyntaxCondition raised(code, text, false);
        for (const std::string &a : lastAdditional()) raised.substitutions.push_back(rx::Value::string(a));
        raised.conditionObject = rx::takeKeptCondition();
        throw raised;
    }
    if (r == NULLOBJECT) return std::string();
    RexxStringObject str = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(r));
    return std::string(t->StringData(str), t->StringLength(str));
}
}
#endif
namespace rx {
// A compiled instance that has no interpreter object yet (dual representation). Handing it to the interpreter creates one.
struct NativeRefBase : ObjectDispatch {
    virtual void *materialize() = 0;   // the interpreter object (valid for the current native call)
};
// Hooks installed by a generated library: package classes created natively, and SELF of a natively dispatched method.
inline std::optional<Value> (*packageClassHook)(const std::string &) = nullptr;
// An interpreter object that is a live instance of one of this library's compiled classes comes back as that native
// instance (its compiled methods then run directly). The hook takes over the global reference it is given.
inline std::optional<Value> (*adoptHook)(void *globalRef) = nullptr;
inline std::optional<Value> (*selfObjectHook)() = nullptr;
struct EnvObject;
// Installed by a generated library with ::ROUTINEs: runs routine~CALL / ~CALLWITH natively when the receiver is one of
// its compiled routines (ours set); otherwise ours stays false and the message goes to the interpreter.
inline MessageResult (*&routineCallHook())(void *routine, const std::string &selector, const std::vector<Value> &args, bool &ours) {
    static MessageResult (*hook)(void *, const std::string &, const std::vector<Value> &, bool &) = nullptr;
    return hook;
}
struct EnvObject final : ObjectDispatch {
    void *handle;
    explicit EnvObject(void *h) : handle(h) {}
    ~EnvObject() override { rxobj::release(handle); }
    // A global reference from the interpreter as a Value: a compiled instance of this library, or an interpreter object.
    static Value adopt(void *globalRef) {
        if (adoptHook) if (auto v = adoptHook(globalRef)) return std::move(*v);
        return Value::fromObject(std::make_shared<EnvObject>(globalRef));
    }
    static Value wrap(const rxobj::Result &r) {
        if (r.kind == 2) return adopt(r.obj);
        return Value::string(r.bytes);
    }
    // A compiled stem object crosses once: it becomes an interpreter stem holding its contents, and the compiled object
    // forwards to that stem from then on (both sides share one stem), as in the hosted tier.
    static void *stemHandle(StemObject &st) {
        std::lock_guard<rx::SpinLock> g(st.lock);
        if (st.remote) {
            if (auto *e = dynamic_cast<EnvObject *>(st.remote.get())) return e->handle;
            throw std::runtime_error("stem object is bound to a non-interpreter object");
        }
        RexxThreadContext *t = rxobj::need();
        rxobj::LocalRefs temps(t);
        RexxStemObject stem = t->NewStem(st.name.c_str());
        void *h = (void *)rxobj::pinRef(t, (RexxObjectPtr)stem);
        auto one = [&](const Value &v) -> RexxObjectPtr {
            std::vector<rxobj::Arg> c; convert({v}, c);
            return c[0].obj ? (RexxObjectPtr)c[0].obj : temps((RexxObjectPtr)t->NewString(c[0].bytes.data(), c[0].bytes.size()));
        };
        if (st.dflt) {
            t->SendMessage1((RexxObjectPtr)stem, "[]=", one(*st.dflt));
            if (t->CheckCondition()) { t->ClearCondition(); throw std::runtime_error("cannot set the stem default"); }
        }
        st.takeElements([&](const std::string &tail, const Value &v) { t->SetStemElement(stem, tail.c_str(), one(v)); });
        st.dflt.reset(); st.dropped.clear();
        st.remote = std::make_shared<EnvObject>(h);
        return h;
    }
    static void convert(const std::vector<Value> &args, std::vector<rxobj::Arg> &out) {
        for (const Value &v : args) {
            rxobj::Arg a;
            if (v.isObject()) {
                auto *k = dynamic_cast<EnvObject *>(v.object.get());
                if (!k && dynamic_cast<NilObject *>(v.object.get())) {
                    a.obj = rxobj::nilObject();
                    if (!a.obj) throw std::runtime_error(".NIL cannot be passed to interpreter messages here");
                    out.push_back(std::move(a));
                    continue;
                }
                if (!k) {
                    if (auto *st = dynamic_cast<StemObject *>(v.object.get())) {
                        a.obj = stemHandle(*st);
                        out.push_back(std::move(a));
                        continue;
                    }
                    if (auto *n = dynamic_cast<NativeRefBase *>(v.object.get())) {
                        a.obj = n->materialize();
                        if (a.obj && rxobj::current)
                            a.hold = std::shared_ptr<void>((void *)rxobj::pinRef(rxobj::current, (RexxObjectPtr)a.obj),
                                                           [](void *h) { if (rxobj::current) rxobj::unpinRef(rxobj::current, h); });
                        out.push_back(std::move(a));
                        continue;
                    }
                    throw std::runtime_error(std::string("only interpreter objects can be passed to interpreter messages (") +
                                             typeid(*v.object).name() + ")");
                }
                if (k->handle == nullptr) a.omitted = true;   // rx::omittedArgument()
                else a.obj = k->handle;
            } else a.bytes = v.bytes;
            out.push_back(std::move(a));
        }
    }
    bool isNilObject() const override { return handle && handle == (void *)rxobj::nilObject(); }
    // Not of a built-in class (its class is not from the REXX package): its string value through REQUEST('STRING').
    // Per class, remembered (the class pinned, so its address stays its own).
    bool requestsString() const override {
        RexxThreadContext *t = rxobj::need();
        rxobj::LocalRefs temps(t);
        RexxObjectPtr cls = temps(t->SendMessage0((RexxObjectPtr)handle, "CLASS"));
        if (t->CheckCondition() || cls == NULLOBJECT) { t->ClearCondition(); return false; }
        static std::mutex gate;
        static std::unordered_map<void *, bool> known;
        { std::lock_guard<std::mutex> g(gate); auto it = known.find((void *)cls); if (it != known.end()) return it->second; }
        bool user = false;
        RexxObjectPtr pkg = temps(t->SendMessage0(cls, "PACKAGE"));
        if (t->CheckCondition()) t->ClearCondition();
        // a class made at run time (.object~subclass(...), .class~new) has no package: not built in either (its instances'
        // behaviour is not primitive: RexxInternalObject::isBaseClass)
        else if (pkg == NULLOBJECT || pkg == t->Nil()) user = true;
        else {
            RexxObjectPtr name = temps(t->SendMessage0(pkg, "NAME"));
            if (t->CheckCondition()) t->ClearCondition();
            else if (name != NULLOBJECT) user = std::string(t->ObjectToStringValue(name)) != "REXX";
        }
        rxobj::pinRef(t, cls);
        std::lock_guard<std::mutex> g(gate);
        known[(void *)cls] = user;
        return user;
    }
    // .Array [] / []= with one index, for an object of the Array class itself (a subclass may override them) that is
    // one-dimensional with items (only an empty array can become multi-dimensional): ArrayClass::getRexx / putRexx
    // for a positive whole-number index written plainly ("17"), done through the native API's ArrayAt / ArrayPut
    // instead of a message (no index or selector string, no index parsing, two interpreter entries instead of six).
    // An empty slot, any other index, or any other array goes through the message.
    mutable signed char plainArray = -1;     // -1 not known yet, 0 no, 1 yes
    static bool plainIndex(const Value &v, std::size_t &index) {
        if (v.isObject()) return false;
        const std::string &s = v.bytes.str();
        if (s.empty() || s.size() > 8 || s[0] < '1' || s[0] > '9') return false;
        std::size_t n = 0;
        for (char c : s) { if (c < '0' || c > '9') return false; n = n * 10 + static_cast<std::size_t>(c - '0'); }
        index = n;
        return true;
    }
    bool isPlainArray() const {
        if (plainArray >= 0) return plainArray == 1;
        RexxThreadContext *t = rxobj::need();
        bool yes = false;
        if (t->IsArray((RexxObjectPtr)handle)) {
            static thread_local RexxObjectPtr arrayClass = NULLOBJECT;
            if (arrayClass == NULLOBJECT) arrayClass = rxobj::pinRef(t, (RexxObjectPtr)t->FindClass("ARRAY"));
            rxobj::LocalRefs temps(t);
            RexxObjectPtr cls = temps(t->SendMessage0((RexxObjectPtr)handle, "CLASS"));
            if (t->CheckCondition()) t->ClearCondition();
            else yes = cls == arrayClass && t->ArraySize((RexxArrayObject)handle) > 0 &&
                       t->ArrayDimension((RexxArrayObject)handle) == 1;
            // (an empty array is asked again next time: it may still get items, or dimensions)
            if (!yes && cls == arrayClass && t->ArraySize((RexxArrayObject)handle) == 0) return false;
        }
        plainArray = yes ? 1 : 0;
        return yes;
    }
    std::optional<MessageResult> arrayAccess(const std::string &selector, const std::vector<Value> &args) const {
        std::size_t index = 0;
        if (selector.size() == 2 && rx::eqLit(selector, "[]") && args.size() == 1) {
            if (!plainIndex(args[0], index) || !isPlainArray()) return std::nullopt;
            RexxThreadContext *t = rxobj::need();
            RexxObjectPtr r = t->ArrayAt((RexxArrayObject)handle, index);
            if (r == NULLOBJECT) return std::nullopt;       // empty or beyond the end: the message answers .nil
            if (t->IsString(r)) {
                Value v = Value::string(std::string(t->StringData((RexxStringObject)r), t->StringLength((RexxStringObject)r)));
                t->ReleaseLocalReference(r);
                return MessageResult(std::move(v));
            }
            rxobj::Result out;
            if (rxobj::isPlainString(t, r)) {
                RexxStringObject s = t->ObjectToString(r);
                out.kind = 1; out.bytes.assign(t->StringData(s), t->StringLength(s));
                t->ReleaseLocalReference((RexxObjectPtr)s);
            } else { out.kind = 2; out.obj = (void *)rxobj::pinRef(t, r); }
            t->ReleaseLocalReference(r);
            return MessageResult(wrap(out));
        }
        if (selector.size() == 3 && rx::eqLit(selector, "[]=") && args.size() == 2) {
            if (!plainIndex(args[1], index) || !isPlainArray()) return std::nullopt;
            const Value &v = args[0];
            if (v.isObject()) {
                auto *e = dynamic_cast<EnvObject *>(v.object.get());
                if (!e || !e->handle) return std::nullopt;   // native objects, omitted: the message path converts them
                rxobj::need()->ArrayPut((RexxArrayObject)handle, (RexxObjectPtr)e->handle, index);
                return MessageResult(std::nullopt);
            }
            RexxThreadContext *t = rxobj::need();
            RexxObjectPtr s = (RexxObjectPtr)t->NewString(v.bytes.str().data(), v.bytes.size());
            t->ArrayPut((RexxArrayObject)handle, s, index);
            t->ReleaseLocalReference(s);
            return MessageResult(std::nullopt);
        }
        return std::nullopt;
    }
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override {
        if (!selector.empty() && selector[0] == '[') if (auto fast = arrayAccess(selector, args)) return *fast;
        if (trappedSendHook()) if (auto trapped = trappedSendHook()(handle, selector, args)) return *trapped;
        // .nil~isNil: Object's ISNIL (RexxObject::isNilRexx), the interpreter's .NIL itself
        if (args.empty() && selector.size() == 5 && rx::eqLit(selector, "ISNIL") && isNilObject()) return Value::string("1");
        // routine~CALL / ~CALLWITH of a routine compiled in this library: run it here (routineCallHook), its arguments
        // staying native (no interpreter frame, no interpreter copy of an argument array)
        if (routineCallHook() && (selector.size() == 4 || selector.size() == 8) &&
            (rx::eqLit(selector, "CALL") || rx::eqLit(selector, "CALLWITH"))) {
            bool ours = false;
            MessageResult r = routineCallHook()(handle, selector, args, ours);
            if (ours) return r;
        }
        std::vector<rxobj::Arg> in; convert(args, in);
        rxobj::Result r; std::string code, text;
        if (!rxobj::send(handle, selector, in, r, code, text)) {
            if (code == "97.1") {
                NoMethod missing(text);
                for (const std::string &a : rxobj::lastAdditional()) missing.substitutions.push_back(Value::string(a));
                missing.conditionObject = takeKeptCondition();
                throw missing;
            }
            SyntaxCondition condition(code, text, false);
            for (const std::string &a : rxobj::lastAdditional()) condition.substitutions.push_back(Value::string(a));
            condition.conditionObject = takeKeptCondition();
            throw condition;
        }
        if (r.kind == 0) return std::nullopt;
        return wrap(r);
    }
    // == and \== of an object that runs Object's own (a Routine compared with .nil: once per clause in the Rexx
    // Parser): identity, answered here for a string, .nil or another interpreter object (asked once per object).
    // (asked at the second comparison of the same object: a wrapper used once is compared by the interpreter, one send
    // instead of three)
    int identityEquality = -1;
    unsigned comparisons = 0;
    Value sendBinary(const std::string &selector, const Value &rhs) override {
        const bool strict = selector.size() == 2 && selector[0] == '=' && selector[1] == '=';
        const bool notStrict = selector.size() == 3 && selector[0] == '\\' && selector[1] == '=' && selector[2] == '=';
        if ((strict || notStrict) && handle) {
            void *other = nullptr; bool known = false;
            if (!rhs.isObject()) known = true;   // a string is never this object
            else if (rhs.object->isNilObject()) { other = rxobj::nilObject(); known = other != nullptr; }
            else if (auto *e = dynamic_cast<EnvObject *>(rhs.object.get())) { other = e->handle; known = other != nullptr; }
            if (known && (identityEquality >= 0 || ++comparisons >= 2)) {
                if (identityEquality < 0) identityEquality = rxobj::objectIdentityEquality(handle) ? 1 : 0;
                if (identityEquality == 1) return Value::string((other == handle) == strict ? "1" : "0");
            }
        }
        auto r = sendMessage(selector, {rhs});
        if (!r) throw std::runtime_error("operator message returned no value: " + selector);
        return *r;
    }
    Value sendUnary(const std::string &selector) override {
        auto r = sendMessage(selector, {});
        if (!r) throw std::runtime_error("operator message returned no value: " + selector);
        return *r;
    }
    std::string display() const override {
        std::vector<rxobj::Arg> none; rxobj::Result r; std::string code, text;
        if (!rxobj::send(handle, "STRING", none, r, code, text) || r.kind != 1)
            throw std::runtime_error("object has no string value");
        return r.bytes;
    }
};
#ifdef RX2CPP_HOST_API
// Install the interpreter String fallback (done at every native entry; cheap and idempotent).
inline MessageResult hostStringMessage(const Value &receiver, const std::string &selector, const std::vector<Value> &args) {
    // Only numeric-sensitive String methods need a routine that carries the caller's NUMERIC settings (a routine call starts a
    // whole activity and is slow); all others are a plain message send.
    static const std::unordered_set<std::string> numericSensitive{
        "ABS","CEILING","FLOOR","ROUND","TRUNC","FORMAT","SIGN","MAX","MIN","SQRT","C2D","D2C","X2D","D2X","B2X","X2B","DATATYPE",
        "+","-","*","/","%","//","**","=","\\=","<",">","<=",">=","<>","><","==","\\==","COMPARE","ISINTEGER","ISWHOLE"};
    std::string upperSelector = selector;
    for (char &c : upperSelector) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
    // RX2CPP_STRING_FALLBACK_STATS=1 prints, at exit, which String messages still reach the interpreter (the next BIFs to mirror).
    struct Stats {
        std::unordered_map<std::string, unsigned long> counts; bool on = std::getenv("RX2CPP_STRING_FALLBACK_STATS") != nullptr;
        ~Stats() { if (on) for (auto &kv : counts) std::fprintf(stderr, "string fallback %s %lu\n", kv.first.c_str(), kv.second); }
    };
    static Stats stats;
    if (stats.on) stats.counts[upperSelector]++;
    if (!numericSensitive.count(upperSelector)) {
        EnvObject str(rxobj::stringHandle(receiver.bytes));
        return str.sendMessage(selector, args);
    }
    std::vector<rxobj::Arg> in; EnvObject::convert(args, in);
    const ActivationNumeric def;
    const ActivationNumeric &n = currentNumeric ? *currentNumeric : def;
    rxobj::Result r; std::string code, text;
    if (!rxobj::sendStringNumeric(receiver.bytes, selector, in, n.digits, n.fuzz, n.engineering, r, code, text)) {
        if (code == "97.1") throw NoMethod(text);
        throw SyntaxCondition(code, text, false);
    }
    if (r.kind == 0) return std::nullopt;
    return EnvObject::wrap(r);
}
inline const bool hostStringFallbackInstalled = (stringMessageFallback() = &hostStringMessage, true);
inline MessageResult hostNilMessage(const std::string &selector, const std::vector<Value> &args) {
    RexxThreadContext *t = rxobj::need();
    EnvObject nil((void *)rxobj::pinRef(t, t->Nil()));   // the interpreter's own .NIL (released with this wrapper)
    return nil.sendMessage(selector, args);
}
inline const bool hostNilFallbackInstalled = (nilMessageFallback() = &hostNilMessage, true);
#endif
#ifdef RX2CPP_HOST_API
inline Value envClass(const std::string &name);
// .CONTEXT inside a native library method: PACKAGE is the library's package; other RexxContext methods fail loudly
// (a compiled method has no interpreter activation to describe).
// A combined library's package as seen from code of one of its source files (compile_program.sh, combine_package.rex):
// NAME is that file's name, as interpreted (the Rexx Parser finds its resources/ next to its own file); any other
// message, and the object handed to the interpreter, is the library's package.
// The answers of the library package's FINDROUTINE (Routine objects), kept: a package's routines and the public routines
// of the packages it requires are fixed once loaded. Compiled code changing the package (ADDROUTINE, ADDPACKAGE, ...)
// empties it. (Interpreted code changing a compiled library's package is not seen.)
struct PackageRoutines { std::mutex lock; std::unordered_map<std::string, Value> found; };
inline PackageRoutines &packageRoutines() { static PackageRoutines *p = new PackageRoutines; return *p; }
inline MessageResult libraryPackageMessage(EnvObject &package, const std::string &selector, const std::vector<Value> &args) {
    auto caselessEquals = [](const std::string &a, const char *b) {
        const std::size_t n = std::strlen(b);
        if (a.size() != n) return false;
        for (std::size_t i = 0; i < n; i++)
            if (std::toupper(static_cast<unsigned char>(a[i])) != static_cast<unsigned char>(b[i])) return false;
        return true;
    };
    static const char *const changes[] = {"ADDROUTINE", "ADDPUBLICROUTINE", "ADDPACKAGE", "LOADPACKAGE", "LOADLIBRARY",
                                          "ADDCLASS", "ADDPUBLICCLASS"};
    if (args.size() == 1 && !args[0].isObject() && caselessEquals(selector, "FINDROUTINE")) {
        std::string key = args[0].bytes.str();
        for (char &c : key) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
        PackageRoutines &r = packageRoutines();
        {
            std::lock_guard<std::mutex> g(r.lock);
            auto it = r.found.find(key);
            if (it != r.found.end()) return it->second;
        }
        MessageResult result = package.sendMessage(selector, args);
        if (result && result->isObject() && !result->object->isNilObject()) {
            std::lock_guard<std::mutex> g(r.lock);
            r.found.insert_or_assign(key, *result);
        }
        return result;
    }
    for (const char *c : changes) if (caselessEquals(selector, c)) {
        std::lock_guard<std::mutex> g(packageRoutines().lock);
        packageRoutines().found.clear();
        break;
    }
    return package.sendMessage(selector, args);
}
// The library's package as compiled code sees it (.context~package): in a combined library, named after the source file
// of the code (`path`; '' is the library's own name).
struct PackageView final : NativeRefBase {
    std::string path;
    std::shared_ptr<EnvObject> package;
    PackageView(std::string p, std::shared_ptr<EnvObject> pkg) : path(std::move(p)), package(std::move(pkg)) {}
    void *materialize() override { return package->handle; }
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override {
        if (args.empty() && !path.empty() && rx::eqLit(selector, "NAME")) return Value::string(path);
        return libraryPackageMessage(*package, selector, args);
    }
    Value sendBinary(const std::string &selector, const Value &rhs) override { return package->sendBinary(selector, rhs); }
    Value sendUnary(const std::string &selector) override { return package->sendUnary(selector); }
    std::string display() const override { return package->display(); }
};
struct LibraryContext final : ObjectDispatch {
    std::string sourcePath;   // the source file of the code using it, in a combined library ('' otherwise)
    LibraryContext() = default;
    explicit LibraryContext(std::string p) : sourcePath(std::move(p)) {}
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &) override {
        if (rx::eqLit(selector, "PACKAGE") && rxobj::libraryPackage() != NULLOBJECT) {
            // (the package object made once: kept for the life of the library)
            static const std::shared_ptr<EnvObject> pkg =
                std::make_shared<EnvObject>((void *)rxobj::pinRef(rxobj::need(), rxobj::libraryPackage()));
            static const Value library = Value::fromObject(std::make_shared<PackageView>(std::string(), pkg));
            if (!sourcePath.empty()) return Value::fromObject(std::make_shared<PackageView>(sourcePath, pkg));
            return library;
        }
        throw SyntaxCondition("98.926", ".CONTEXT~" + selector + " is not available in compiled code", false);
    }
    std::string display() const override { return "a RexxContext"; }
};
// The interpreter condition object kept by the last failing interpreter call (see rxobj::keepCondition).
inline std::shared_ptr<ObjectDispatch> takeKeptCondition() {
    void *h = rxobj::keptCondition();
    if (!h) return nullptr;
    rxobj::keptCondition() = nullptr;
    return std::make_shared<EnvObject>(h);
}
// ---- SIGNAL ON / OFF, labels and CONDITION() in a compiled activation (method or package routine) ----
// A library-specific way to recognise "a condition is pending in the interpreter" (the template's PendingCondition):
// returns the condition object and clears the condition.
inline std::shared_ptr<ObjectDispatch> (*pendingConditionHook)(const std::exception &) = nullptr;
struct RaisedCondition {
    std::string name = "SYNTAX";
    std::string code;
    std::vector<Value> substitutions;
    std::shared_ptr<ObjectDispatch> object;
};
inline bool numericCode(const std::string &c) {
    return !c.empty() && c.find('.') != std::string::npos && c.find_first_not_of("0123456789.") == std::string::npos;
}
// The condition an exception from compiled code stands for (false: not a condition, e.g. EXIT).
inline RexxObjectPtr interpreterHelper(RexxThreadContext *t, rxobj::LocalRefs &temps, RexxRoutineObject &routine,
                                       const char *name, const char *source, const std::vector<Value> &args);
// The condition object of a NOVALUE raised by compiled code (DESCRIPTION: the variable's name), as the interpreter makes it.
inline std::shared_ptr<ObjectDispatch> noValueConditionObject(const std::string &variable) {
    RexxThreadContext *t = rxobj::need();
    rxobj::LocalRefs temps(t);
    static thread_local RexxRoutineObject helper = NULLOBJECT;
    // (RAISE NOVALUE does not reach a trap: an unset variable is read instead, inside INTERPRET so any name works.)
    static const char source[] = "use arg rx2cppName\nsignal on novalue name rx2cppNovalue\n"
                                 "interpret 'rx2cppValue =' rx2cppName\nreturn .nil\nrx2cppNovalue: return condition('O')\n";
    RexxObjectPtr r = interpreterHelper(t, temps, helper, "rx2cpp_novalue", source, {Value::string(variable)});
    return std::make_shared<EnvObject>((void *)rxobj::pinRef(t, r));
}
// LOSTDIGITS raised by native arithmetic (rx::checkLostDigits): the interpreter's own condition object for the operand.
inline void raiseLostDigits(const Value &operand) {
    RexxThreadContext *t = rxobj::need();
    rxobj::LocalRefs temps(t);
    static thread_local RexxRoutineObject helper = NULLOBJECT;
    static const char source[] = "use arg rx2cppNumber\nsignal on lostdigits name rx2cppLost\nnumeric digits 1\n"
                                 "rx2cppValue = rx2cppNumber + 0\nreturn .nil\nrx2cppLost: return condition('O')\n";
    RexxObjectPtr r = interpreterHelper(t, temps, helper, "rx2cpp_lostdigits", source, {operand});
    throw NotReadyCondition(std::make_shared<EnvObject>((void *)rxobj::pinRef(t, r)), "LOSTDIGITS");
}
inline const bool lostDigitsInstalled = (lostDigitsHook() = &raiseLostDigits, true);
// RAISE of a non-SYNTAX condition, reaching the native entry of a compiled method or routine: the interpreter raises
// it from a small routine whose caller is this native activation, which keeps it and raises it in its own caller when
// it returns (NativeActivation::checkConditions: trapped there, or ignored; the RESULT is the method's result).
inline std::string raiseCommand(const RaiseToCaller &r, std::vector<Value> &args) {
    std::string cmd = "raise " + r.name;
    args = {Value::string(r.name)};
    auto add = [&](const std::optional<Value> &v, const char *form) {
        if (!v) return;
        args.push_back(*v);
        cmd += std::string(" ") + form + " (arg(" + std::to_string(args.size()) + "))";
    };
    if (r.rc) { args.push_back(*r.rc); cmd += " (arg(" + std::to_string(args.size()) + "))"; }
    add(r.description, "description");
    add(r.additional, "additional");
    add(r.result, "return");
    return cmd;
}
// RaiseCondition (the API) makes the condition object and this native activation keeps it (willTrap: an API raise);
// RC, which the API cannot pass, goes into the kept object. When the method returns, NativeActivation::checkConditions
// raises it in the caller - trapped there, or ignored with the RESULT as the method's result.
// (Known gap: an untrapped HALT / NOMETHOD is ignored here, where RexxActivation::raise makes it error 4.1 / 97.)
inline void raiseToCaller(const RaiseToCaller &r) {
    RexxThreadContext *t = rxobj::need();
    rxobj::LocalRefs temps(t);
    std::vector<rxobj::Arg> conv;
    auto object = [&](const Value &v) -> RexxObjectPtr {
        conv.clear(); EnvObject::convert({v}, conv);
        return conv[0].obj ? (RexxObjectPtr)conv[0].obj : temps((RexxObjectPtr)t->NewString(conv[0].bytes.data(), conv[0].bytes.size()));
    };
    RexxStringObject description = NULLOBJECT;
    if (r.description) {
        RexxObjectPtr d = object(*r.description);
        description = t->IsString(d) ? (RexxStringObject)d : (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(d));
    }
    RexxObjectPtr additional = r.additional ? object(*r.additional) : NULLOBJECT;
    RexxObjectPtr result = r.result ? object(*r.result) : NULLOBJECT;
    RexxObjectPtr rc = r.rc ? object(*r.rc) : NULLOBJECT;
    t->RaiseCondition(r.name.c_str(), description, additional, result);
    if (rc != NULLOBJECT) if (RexxDirectoryObject kept = t->GetConditionInfo()) t->DirectoryPut(kept, rc, "RC");
}
// The same condition as an object, for a compiled caller that traps it (describeRaised).
inline std::shared_ptr<ObjectDispatch> raisedConditionObject(const RaiseToCaller &r) {
    RexxThreadContext *t = rxobj::need();
    rxobj::LocalRefs temps(t);
    std::vector<Value> args;
    const std::string cmd = raiseCommand(r, args) + "\n";
    // The RAISE runs in a routine called by a helper routine, which is its caller and traps it (an internal routine
    // would do, but the interpreter loses a condition raised in an internal routine of a routine run by CALL).
    static const char outer[] = "use arg rx2cppInner, rx2cppArgs\nsignal on any name rx2cppCaught\n"
                                "rx2cppIgnored = rx2cppInner~callWith(rx2cppArgs)\nreturn .nil\nrx2cppCaught: return condition('O')\n";
    RexxRoutineObject inner = (RexxRoutineObject)temps((RexxObjectPtr)rxobj::transientRoutine(t, t->NewRoutine("rx2cpp_raise", cmd.c_str(), cmd.size())));
    RexxRoutineObject routine = (RexxRoutineObject)temps((RexxObjectPtr)rxobj::transientRoutine(t, t->NewRoutine("rx2cpp_raised", outer, sizeof(outer) - 1)));
    RexxArrayObject innerArgs = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(args.size()));
    std::vector<rxobj::Arg> conv;
    for (std::size_t i = 0; i < args.size(); ++i) {
        conv.clear(); EnvObject::convert({args[i]}, conv);
        t->ArrayPut(innerArgs, conv[0].obj ? (RexxObjectPtr)conv[0].obj : temps((RexxObjectPtr)t->NewString(conv[0].bytes.data(), conv[0].bytes.size())), i + 1);
    }
    RexxArrayObject list = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(2));
    t->ArrayPut(list, (RexxObjectPtr)inner, 1);
    t->ArrayPut(list, (RexxObjectPtr)innerArgs, 2);
    RexxObjectPtr o = temps(t->CallRoutine(routine, list));
    if (t->CheckCondition()) { t->ClearCondition(); return nullptr; }
    if (o == NULLOBJECT || o == t->Nil()) return nullptr;
    return std::make_shared<EnvObject>((void *)rxobj::pinRef(t, o));
}
inline bool describeRaised(std::exception_ptr e, RaisedCondition &out) {
    try { std::rethrow_exception(e); }
    catch (const SyntaxCondition &c) {
        out.object = c.conditionObject;
        if (numericCode(c.code)) { out.code = c.code; out.substitutions = c.substitutions; }
        else { out.code = "98.900"; out.substitutions = {Value::string(c.what())}; }
        return true;
    }
    catch (const NoMethod &m) {
        out.object = m.conditionObject;
        // The interpreter's own "does not understand" (97.1) passes through as is; a compiled object's is 98.900.
        if (m.conditionObject) { out.code = "97.1"; out.substitutions = m.substitutions; }
        else { out.code = "98.900"; out.substitutions = {Value::string(m.what())}; }
        return true;
    }
    catch (const NotReadyCondition &n) { out.name = n.name; out.object = n.conditionObject; return true; }
    catch (const NoValueCondition &n) { out.name = "NOVALUE"; out.object = noValueConditionObject(n.variable); return true; }
    catch (const RaiseToCaller &r) {
        if (!r.delivered) return false;   // RAISE ends its own activation: the condition is its caller's
        out.name = r.name;
        out.object = raisedConditionObject(r);
        return true;
    }
    catch (const SignalJump &) { return false; }
    catch (const std::exception &x) {
        if (pendingConditionHook) if (auto o = pendingConditionHook(x)) { out.object = o; return true; }
        out.code = "98.900"; out.substitutions = {Value::string(x.what())};
        return true;
    }
    catch (...) { return false; }
}
inline Value conditionEntry(const std::shared_ptr<ObjectDispatch> &object, const char *key) {
    MessageResult v = object->sendMessage("[]", {Value::string(key)});
    return v ? *v : nil();
}
struct MethodTraps {
    enum Kind { SYNTAX, ERROR, FAILURE, NOVALUE, NOTREADY, LOSTDIGITS, NOSTRING, ANY, HALT, NOMETHOD, KINDS,
                USERS = 16, SLOTS = KINDS + USERS };   // slots past KINDS: USER conditions, in the order first trapped
    bool on[SLOTS] = {};
    bool callMode[SLOTS] = {};                 // CALL ON (the trap stays on; the handler is called at the clause boundary)
    bool delayed[SLOTS] = {};                  // its CALL ON handler is running (CONDITION('S') = DELAY)
    bool novalueOn = false;                    // SIGNAL ON NOVALUE or ANY: reading an unset variable raises NOVALUE
    const bool *savedNovalue = nullptr;
    bool lostDigitsOn = false;                 // SIGNAL ON LOSTDIGITS or ANY: native arithmetic raises LOSTDIGITS
    const bool *savedLostDigits = nullptr;
    int label[SLOTS] = {};
    // The names of USER conditions and of missing SIGNAL ON labels, kept apart and made only when one is set (an
    // activation is entered on every internal routine call: its traps cost nothing until used).
    struct Names { std::string user[USERS]; std::string missing[SLOTS]; };
    std::unique_ptr<Names> names_;
    Names &names() { if (!names_) names_ = std::make_unique<Names>(); return *names_; }
    const std::string &userName(int u) const { static const std::string none; return names_ ? names_->user[u] : none; }
    const std::string &missing(int k) const { static const std::string none; return names_ ? names_->missing[k] : none; }
    int users = 0;
    bool has = false;                          // a condition was trapped in this activation (or its caller's, inherited)
    std::string name;
    std::string instruction;                   // SIGNAL or CALL
    std::shared_ptr<ObjectDispatch> object;
    struct Queued { int slot; std::string name; std::shared_ptr<ObjectDispatch> object; };
    std::vector<Queued> queue;                 // CALL ON conditions waiting for the clause boundary (processTraps)
    MethodTraps *saved = nullptr;
    bool internal = false;                     // an internal routine's activation (inherited from its caller)
    // An internal routine (CALL label, label(...), a CALL ON handler) starts with a copy of its caller's trap settings
    // and condition information (RexxActivation INTERNALCALL); the caller sets inheritNext just before entering it.
    static MethodTraps *&inheritNext() { static thread_local MethodTraps *p = nullptr; return p; }
    struct Handing { std::string name; std::shared_ptr<ObjectDispatch> object; bool active = false; };
    static Handing &handing() { static thread_local Handing h; return h; }   // a CALL ON handler's condition
    // The running activation's traps are known to the stream built-ins (NOTREADY), through its ActivationScope.
    MethodTraps() : savedNovalue(novalueArmed), savedLostDigits(lostDigitsArmed) {
        if (MethodTraps *from = std::exchange(inheritNext(), nullptr)) {
            internal = true;
            std::memcpy(on, from->on, sizeof on); std::memcpy(callMode, from->callMode, sizeof callMode);
            std::memcpy(delayed, from->delayed, sizeof delayed); std::memcpy(label, from->label, sizeof label);
            if (from->names_) names_ = std::make_unique<Names>(*from->names_);
            users = from->users; has = from->has; name = from->name; instruction = from->instruction; object = from->object;
        }
        Handing &h = handing();
        if (h.active) { has = true; name = h.name; instruction = "CALL"; object = h.object; h = Handing(); }
        if (ActivationScope *a = ActivationScope::current()) { saved = a->traps; a->traps = this; }
        novalueArmed = &novalueOn;
        lostDigitsArmed = &lostDigitsOn;
        syncNovalue();
    }
    ~MethodTraps() {
        if (ActivationScope *a = ActivationScope::current()) if (a->traps == this) a->traps = saved;
        novalueArmed = savedNovalue;
        lostDigitsArmed = savedLostDigits;
    }
    // The slot that traps condition c (k its slot or -1), or -1: c's own trap, else ANY (CALL ON ANY cannot take the
    // conditions CALL ON does not trap: TrapHandler::canHandle).
    int trapping(const std::string &c, int k) const {
        if (k >= 0 && on[k]) return k;
        if (!on[ANY]) return -1;
        if (callMode[ANY] && (c == "SYNTAX" || c == "NOVALUE" || c == "LOSTDIGITS" || c == "NOSTRING" || c == "NOMETHOD")) return -1;
        return ANY;
    }
    void syncNovalue() {
        novalueOn = (on[NOVALUE] && !callMode[NOVALUE]) || (on[ANY] && !callMode[ANY]);
        lostDigitsOn = (on[LOSTDIGITS] && !callMode[LOSTDIGITS]) || (on[ANY] && !callMode[ANY]);
    }
    MethodTraps(const MethodTraps &) = delete;
    MethodTraps &operator=(const MethodTraps &) = delete;
    // Is NOTREADY trapped in the running activation (SIGNAL / CALL ON NOTREADY, or ANY)?
    static bool notReadyArmed() {
        ActivationScope *a = ActivationScope::current();
        return a && a->traps && a->traps->trapping("NOTREADY", NOTREADY) >= 0;
    }
    // Which conditions raised inside the interpreter the running activation traps, as bits: 1 NOTREADY (SIGNAL ON),
    // 8 NOTREADY (CALL ON), 2 NOSTRING, 4 LOSTDIGITS; 0 none.
    static int interpreterConditionMode() {
        ActivationScope *a = ActivationScope::current();
        if (!a || !a->traps) return 0;
        const MethodTraps &m = *a->traps;
        int mode = 0;
        const int notReady = m.trapping("NOTREADY", NOTREADY);
        if (notReady >= 0) mode |= m.callMode[notReady] ? 8 : 1;
        if (m.trapping("NOSTRING", NOSTRING) >= 0) mode |= 2;
        if (m.trapping("LOSTDIGITS", LOSTDIGITS) >= 0) mode |= 4;
        return mode;
    }
    // Which command conditions the running activation traps, as bits: 1 ERROR, 2 FAILURE, 4 ANY.
    static int commandConditionMode() {
        ActivationScope *a = ActivationScope::current();
        if (!a || !a->traps) return 0;
        const MethodTraps &m = *a->traps;
        return (m.on[ERROR] ? 1 : 0) | (m.on[FAILURE] ? 2 : 0) | (m.on[ANY] ? 4 : 0);
    }
    // The running activation's traps, for INTERPRET: the conditions (not SYNTAX) the interpreted string must hand back,
    // each with its form (true: CALL ON).
    static std::vector<std::pair<std::string, bool>> armedConditions() {
        std::vector<std::pair<std::string, bool>> names;
        ActivationScope *a = ActivationScope::current();
        if (!a || !a->traps) return names;
        static const char *const kinds[] = {"SYNTAX", "ERROR", "FAILURE", "NOVALUE", "NOTREADY", "LOSTDIGITS", "NOSTRING", "ANY",
                                            "HALT", "NOMETHOD"};
        const MethodTraps &m = *a->traps;
        for (int k = ERROR; k < KINDS; ++k) if (m.on[k]) names.emplace_back(kinds[k], m.callMode[k]);
        for (int u = 0; u < m.users; ++u) if (m.on[KINDS + u]) names.emplace_back(m.userName(u), m.callMode[KINDS + u]);
        return names;
    }
    static int kindOf(const std::string &c) {
        if (c == "SYNTAX") return SYNTAX;
        if (c == "ERROR") return ERROR;
        if (c == "FAILURE") return FAILURE;
        if (c == "NOVALUE") return NOVALUE;
        if (c == "NOTREADY") return NOTREADY;
        if (c == "LOSTDIGITS") return LOSTDIGITS;
        if (c == "NOSTRING") return NOSTRING;
        if (c == "ANY") return ANY;
        if (c == "HALT") return HALT;
        if (c == "NOMETHOD") return NOMETHOD;
        return -1;
    }
    // The slot of a condition: its kind, or the slot of a USER condition (a new one when create).
    int slotOf(const std::string &c, bool create) {
        const int k = kindOf(c);
        if (k >= 0) return k;
        for (int u = 0; u < users; ++u) if (userName(u) == c) return KINDS + u;
        if (!create) return -1;
        if (users == USERS) throw std::runtime_error("too many USER condition traps in one activation");
        names().user[users] = c;
        return KINDS + users++;
    }
    int find(const std::string &c) const { return const_cast<MethodTraps *>(this)->slotOf(c, false); }
    // (names_->missing[k]: SIGNAL ON c NAME label with no such label: 16.1 when c is raised)
    void set(const char *c, int target) { const int k = slotOf(c, true); on[k] = true; callMode[k] = false; label[k] = target; if (names_) names_->missing[k].clear(); syncNovalue(); }
    void setMissing(const char *c, const std::string &name) { const int k = slotOf(c, true); on[k] = true; callMode[k] = false; label[k] = -1; names().missing[k] = name; syncNovalue(); }
    void setCall(const char *c, int target) { const int k = slotOf(c, true); on[k] = true; callMode[k] = true; delayed[k] = false; label[k] = target; if (names_) names_->missing[k].clear(); syncNovalue(); }
    void clear(const char *c) { const int k = slotOf(c, true); on[k] = false; callMode[k] = false; syncNovalue(); }
    // An exception reached the activation: the label to continue at (the trap is turned off), or -1 to let it go on.
    int fire(Variables &vars, std::size_t line, std::exception_ptr e) {
        if (internal) {   // a RAISE SYNTAX without RETURN in an internal routine is for the top level only
            try { std::rethrow_exception(e); } catch (const SyntaxCondition &c) { if (c.skipInternalTraps) return -1; } catch (...) {}
        }
        RaisedCondition raised;
        if (!describeRaised(e, raised)) return -1;
        const int use = trapping(raised.name, find(raised.name));
        if (use < 0 || callMode[use]) return -1;    // a CALL ON trap never unwinds (conditions reach it by deliver)
        on[use] = false;
        syncNovalue();
        if (!raised.object) {
            std::vector<rxobj::Arg> subs; EnvObject::convert(raised.substitutions, subs);
            raised.object = std::make_shared<EnvObject>(rxobj::conditionObject(raised.code, subs));
        }
        has = true;
        name = raised.name;
        instruction = "SIGNAL";
        object = raised.object;
        if (rx::eqLit(name, "SYNTAX") || rx::eqLit(name, "ERROR") || rx::eqLit(name, "FAILURE")) rx::set(vars, "RC", conditionEntry(object, "RC"));
        rx::set(vars, "SIGL", Value::string(std::to_string(line)));
        if (label[use] < 0) {
            SyntaxCondition e("16.1", "Label \"" + missing(use) + "\" not found", false);
            e.substitutions.push_back(Value::string(missing(use)));
            throw e;
        }
        return label[use];
    }
    // A condition raised in the running activation without unwinding it (RexxActivation::trap): a SIGNAL ON trap takes
    // it now (thrown to fire); a CALL ON trap queues it for the clause boundary; otherwise it is ignored. Answers
    // whether it was trapped.
    static bool deliver(const std::string &c, const std::shared_ptr<ObjectDispatch> &o) {
        ActivationScope *a = ActivationScope::current();
        if (!a || !a->traps) return false;
        MethodTraps &m = *a->traps;
        const int use = m.trapping(c, m.find(c));
        if (use < 0) return false;
        if (!m.callMode[use]) throw NotReadyCondition(o, c);
        o->sendMessage("PUT", {Value::string("CALL"), Value::string("INSTRUCTION")});
        m.queue.push_back({use, c, o});
        return true;
    }
    // processTraps: a queued condition whose trap is not delayed, if any (its handler is called next).
    bool ready() const {
        for (const Queued &q : queue) if (!delayed[q.slot]) return true;
        return false;
    }
    // Take the next one: RC from its condition object, the trap delayed, and the handler's condition handed over.
    Queued take(Variables &vars) {
        for (auto i = queue.begin(); i != queue.end(); ++i) {
            if (delayed[i->slot]) continue;
            Queued q = *i;
            queue.erase(i);
            Value rc = conditionEntry(q.object, "RC");
            if (!rc.isObject()) rx::set(vars, "RC", rc);
            else if (!dynamic_cast<NilObject *>(rc.object.get())) rx::set(vars, "RC", rc);
            delayed[q.slot] = true;
            inheritNext() = this;
            handing() = Handing{q.name, q.object, true};
            return q;
        }
        throw std::runtime_error("no CALL ON condition is ready");
    }
    void undelay(int slot) { delayed[slot] = false; }
    // CONDITION([option]) of this activation.
    Value condition(const std::optional<Value> &arg) const {
        char option = 'I';
        if (arg && !arg->isObject() && !arg->bytes.empty())
            option = static_cast<char>(std::toupper(static_cast<unsigned char>(arg->bytes[0])));
        switch (option) {
        case 'A': return has ? conditionEntry(object, "ADDITIONAL") : nil();
        case 'O': return has ? Value::fromObject(object) : nil();
        case 'C': return Value::string(has ? name : std::string());
        case 'I': return Value::string(has ? instruction : std::string());
        case 'D': {
            if (!has) return Value::string(std::string());
            Value d = conditionEntry(object, "DESCRIPTION");
            return d.isObject() ? Value::string(std::string()) : d;
        }
        case 'S': {
            if (!has) return Value::string(std::string());
            const int k = find(name);
            if (k < 0 || !on[k]) return Value::string("OFF");
            return Value::string(delayed[k] ? "DELAY" : "ON");
        }
        default: throw SyntaxCondition("40.904", "CONDITION option must be one of ACDIOS", false);
        }
    }
    // RAISE PROPAGATE: the trapped condition again, to the caller.
    [[noreturn]] void propagate() const {
        if (!has) throw SyntaxCondition("93.900", "RAISE PROPAGATE outside a condition trap", false);
        Value code = conditionEntry(object, "CODE");
        SyntaxCondition again(code.isObject() ? std::string("98.900") : code.bytes.str(), name, false);
        Value additional = conditionEntry(object, "ADDITIONAL");
        if (additional.isObject() && !dynamic_cast<NilObject *>(additional.object.get()))
            for (const Value &item : arrayItems(additional)) again.substitutions.push_back(item);
        again.conditionObject = object;
        throw again;
    }
};
// A RAISE that ended a compiled callee reaches its compiled caller (RexxActivation::raise: the sender's trap). A caller
// that traps the condition with SIGNAL ON (it or ANY) gets it now: it is rethrown, delivered, to the caller's
// MethodTraps; with CALL ON it is queued for the caller's clause boundary. Otherwise HALT is error 4.1 and NOMETHOD
// 97.1 / 97.5, and any other condition is ignored. Unless it unwinds, the call answers the RETURN / EXIT value.
inline std::optional<Value> raisedInCaller(const RaiseToCaller &r) {
    if (ActivationScope *a = ActivationScope::current()) if (a->traps) {
        MethodTraps &m = *a->traps;
        const int use = m.trapping(r.name, m.find(r.name));
        if (use >= 0) {
            if (!m.callMode[use]) { RaiseToCaller d = r; d.delivered = true; throw d; }
            if (auto o = raisedConditionObject(r)) {
                o->sendMessage("PUT", {Value::string("CALL"), Value::string("INSTRUCTION")});
                m.queue.push_back({use, r.name, o});
            }
            return r.result;
        }
    }
    if (rx::eqLit(r.name, "HALT")) {
        SyntaxCondition e("4.1", "Program interrupted with HALT condition", false);
        e.substitutions.push_back(Value::string("HALT"));
        throw e;
    }
    if (rx::eqLit(r.name, "NOMETHOD")) {
        if (r.additional && r.description) {
            SyntaxCondition e("97.1", "does not understand message", false);
            e.substitutions = {*r.additional, *r.description};
            throw e;
        }
        throw SyntaxCondition("97.5", "An unhandled NOMETHOD condition has been raised", false);
    }
    return r.result;
}
// NOSTRING (RexxObject::requestString used STRING): raised in the running activation when it traps it.
inline void raiseNoString(const Value &text, const Value &object) {
    ActivationScope *a = ActivationScope::current();
    if (!a || !a->traps || a->traps->trapping("NOSTRING", MethodTraps::NOSTRING) < 0) return;
    RaiseToCaller r;
    r.name = "NOSTRING"; r.description = text; r.additional = object;
    if (auto o = raisedConditionObject(r)) MethodTraps::deliver("NOSTRING", o);
}
inline const bool noStringInstalled = (noStringHook() = &raiseNoString, true);
// .RS of the running activation (RexxActivation::rexxVariable): before any command the symbol's own name ".RS".
inline Value returnStatusValue() {
    ActivationScope *a = ActivationScope::current();
    if (!a || !a->returnStatus) return Value::string(".RS");
    return Value::number(std::to_string(*a->returnStatus));
}
// After a REPLY, the running native method entry takes the locks it runs on from now on (the native package installs
// it): the object's lock for a guarded method (GUARD ON, the entry's compiled-scope lock let go while it waits), and
// the compiled-scope lock when the method ran under its caller's until the reply.
inline void (*&replyLocksHook())(bool) { static void (*hook)(bool) = nullptr; return hook; }
// GUARD in a compiled method (RexxInstructionGuard): the native package installs the hook, which acts on the running
// native method entry: 1 GUARD ON, 0 GUARD OFF (each only when the state changes, as RexxActivation::guardOn / Off),
// 2 wait for a change to the object's compiled variables (the object's lock let go meanwhile when held, then taken back:
// RexxActivation::guardWait).
inline void (*&guardHook())(int) { static void (*hook)(int) = nullptr; return hook; }
inline void guardInstruction(bool on) { if (guardHook()) guardHook()(on ? 1 : 0); }
template <class Test> void guardWhen(bool on, Test &&test) {
    guardInstruction(on);
    while (!test()) {
        if (!guardHook()) throw std::runtime_error("GUARD WHEN outside a native method entry");
        guardHook()(2);
    }
}
// REPLY (RexxActivation::reply). A method that replies runs on an activity of its own from the start: its declaration
// stub (with the method's guard, on the caller's activity, so the object stays locked by the caller until the reply)
// starts it unguarded with a reply box (an interpreter object of the declaration package) as an extra last argument
// and waits on the box. ReplyScope takes the box off the arguments for the method's activation; REPLY sends the box
// its value (the stub returns it to the caller, its lock goes) and a guarded method then takes the object's lock on
// its own activity (waiting while the caller's activity holds it, as interpreted) and runs on. RETURN / EXIT with a
// value after it: 98.936 / 98.937 (afterReply). A second REPLY: 98.935. In an internal routine (or without a box):
// 99.919.
struct ReplyScope {
    std::vector<std::optional<Value>> arguments;
    std::optional<Value> box;
    bool guarded;
    bool replied = false;
    ReplyScope *saved;
    static ReplyScope *&current() { thread_local ReplyScope *c = nullptr; return c; }
    ReplyScope(const std::vector<std::optional<Value>> &args, bool guard) : arguments(args), guarded(guard), saved(current()) {
        if (!arguments.empty()) { box = arguments.back(); arguments.pop_back(); }
        current() = this;
    }
    ~ReplyScope() { current() = saved; }
    ReplyScope(const ReplyScope &) = delete;
    ReplyScope &operator=(const ReplyScope &) = delete;
};
inline void replyInstruction(const std::optional<Value> &value, bool internal) {
    ReplyScope *r = ReplyScope::current();
    if (internal || !r || !r->box) raiseSyntaxCode(Value::number("99.919"), {});
    if (r->replied) raiseSyntaxCode(Value::number("98.935"), {});
    r->replied = true;
    std::vector<Value> args;
    if (value) args.push_back(*value);
    sendMessage(*r->box, "REPLY", args);
    if (replyLocksHook()) replyLocksHook()(r->guarded);
}
inline Value afterReply(Value value, bool exitForm, bool internal) {
    ReplyScope *r = ReplyScope::current();
    if (!internal && r && r->replied) raiseSyntaxCode(Value::number(exitForm ? "98.937" : "98.936"), {});
    return value;
}
// A compiled package routine called by compiled code: a RAISE that ends it reaches this caller (raisedInCaller).
template <class Call> Value runRaising(Call &&call) {
    try { return call(); }
    catch (const RaiseToCaller &r) {
        noResultPending() = false;
        std::optional<Value> v = raisedInCaller(r);
        return v ? *v : noResult();
    }
}
// CONDITION() in an activation that traps nothing: no condition information.
inline Value noCondition(const std::optional<Value> &arg) {
    char option = 'I';
    if (arg && !arg->isObject() && !arg->bytes.empty())
        option = static_cast<char>(std::toupper(static_cast<unsigned char>(arg->bytes[0])));
    if (option == 'A' || option == 'O') return nil();
    return Value::string(std::string());
}
inline Value interpreterVersion() { return Value::string(rxobj::interpreterVersion()); }
// The interpreter's system name (first word of PARSE SOURCE: LINUX, WindowsNT, ...).
inline std::string interpreterSystem() {
    static std::string name;
    static std::once_flag once;
    std::call_once(once, [] {
        RexxThreadContext *t = rxobj::need();
        static const char source[] = "parse source s .\nreturn s\n";
        RexxRoutineObject r = rxobj::internalRoutine(t, t->NewRoutine("rx2cpp_system", source, sizeof(source) - 1));
        RexxObjectPtr v = r == NULLOBJECT ? NULLOBJECT : t->CallRoutine(r, t->NewArray(0));
        if (t->CheckCondition() || v == NULLOBJECT) { t->ClearCondition(); throw std::runtime_error("cannot read PARSE SOURCE"); }
        name = t->ObjectToStringValue(v);
    });
    return name;
}
inline Value libraryContext() { static const Value c = Value::fromObject(std::make_shared<LibraryContext>()); return c; }
// .CONTEXT of code from one source file of a combined library (its path: a literal, so one object per access site)
inline Value libraryContext(const char *sourcePath) { return Value::fromObject(std::make_shared<LibraryContext>(sourcePath)); }
inline Value argumentArray(const std::vector<std::optional<Value>> &args);
inline Value selfObject();
// .METHODS / .ROUTINES / .RESOURCES in a native library (RexxActivation::rexxVariable: the package's own table,
// settings.parentCode->getMethods() / getRoutines() / getResources(); the symbol's own name when the package has none).
// The Package methods answer copies (DEFINEDMETHODS, ROUTINES, RESOURCES), so one is taken at the first use and
// answered every time after, as the same object, as interpreted. A package with none has an empty copy: the name.
struct PackageTable { bool taken = false; std::optional<Value> table; };
inline Value packageTable(PackageTable &kept, const char *selector, const char *symbol) {
    if (!kept.taken) {
        RexxThreadContext *t = rxobj::need();
        RexxObjectPtr pkg = rxobj::libraryPackage();
        RexxObjectPtr v = pkg == NULLOBJECT ? NULLOBJECT : t->SendMessage0(pkg, selector);
        if (t->CheckCondition()) { t->ClearCondition(); v = NULLOBJECT; }
        if (v != NULLOBJECT && v != t->Nil()) {
            // (the declaration package also holds rx2cpp's own routines, RX2CPP_MAIN, RX2CPP_TAKE, ...: not the program's)
            RexxObjectPtr indexes = t->SendMessage0(v, "ALLINDEXES");
            if (indexes != NULLOBJECT && !t->CheckCondition() && t->IsArray(indexes)) {
                size_t count = t->ArrayItems((RexxArrayObject)indexes);
                for (size_t i = 1; i <= count; ++i) {
                    RexxObjectPtr index = t->ArrayAt((RexxArrayObject)indexes, i);
                    if (index == NULLOBJECT || !t->IsString(index)) continue;
                    if (std::strncmp(t->StringData((RexxStringObject)index), "RX2CPP_", 7) == 0) {
                        RexxObjectPtr gone = t->SendMessage1(v, "REMOVE", index);
                        if (gone != NULLOBJECT) t->ReleaseLocalReference(gone);
                    }
                    t->ReleaseLocalReference(index);
                }
            }
            if (t->CheckCondition()) t->ClearCondition();
            if (indexes != NULLOBJECT) t->ReleaseLocalReference(indexes);
            RexxObjectPtr n = t->SendMessage0(v, "ITEMS");
            wholenumber_t items = 0;
            if (n == NULLOBJECT || !t->ObjectToWholeNumber(n, &items)) { t->ClearCondition(); items = 0; }
            if (n != NULLOBJECT) t->ReleaseLocalReference(n);
            if (items > 0) kept.table = Value::fromObject(std::make_shared<EnvObject>((void *)rxobj::pinRef(t, v)));
            t->ReleaseLocalReference(v);
        }
        kept.taken = true;
    }
    if (!kept.table) return Value::string(symbol);
    return *kept.table;
}
inline Value packageMethodsSpecial() { static PackageTable k; return packageTable(k, "DEFINEDMETHODS", ".METHODS"); }
inline Value packageRoutinesSpecial() { static PackageTable k; return packageTable(k, "ROUTINES", ".ROUTINES"); }
inline Value packageResourcesSpecial() { static PackageTable k; return packageTable(k, "RESOURCES", ".RESOURCES"); }
// .CONTEXT of a compiled activation (RexxContext, ContextClass.cpp): taken where .CONTEXT is evaluated - the NUMERIC
// settings, arguments, condition, clause line, name and (unless only another method follows) the variables.
struct ActivationContext final : ObjectDispatch {
    ActivationNumeric numeric;
    std::vector<std::optional<Value>> args;
    Value condition = nil();
    Value line = nil();
    std::string name;
    std::string scopeClass;          // the method's class ('' for a routine)
    std::string selector;            // the method / routine whose executable this is
    bool method = false, classSide = false;
    Value self = nil();
    bool hasVariables = false;
    std::vector<std::pair<std::string, Value>> variables;
    std::optional<Value> returnStatus;
    MessageResult sendMessage(const std::string &s, const std::vector<Value> &a) override {
        if (s == "DIGITS") return Value::number(std::to_string(numeric.digits));
        if (s == "FUZZ") return Value::number(std::to_string(numeric.fuzz));
        if (s == "FORM") return Value::string(numeric.engineering ? "ENGINEERING" : "SCIENTIFIC");
        if (s == "ARGS") return argumentArray(args);
        if (s == "CONDITION") {
            if (!condition.isObject() || dynamic_cast<NilObject *>(condition.object.get())) return nil();
            MessageResult copy = condition.object->sendMessage("COPY", {});
            return copy ? *copy : condition;
        }
        if (s == "LINE") return line;
        if (s == "NAME") return Value::string(name);
        if (s == "RS") return returnStatus ? *returnStatus : nil();
        if (s == "PACKAGE") return libraryContext().object->sendMessage("PACKAGE", {});
        if (s == "EXECUTABLE") return executable();
        if (s == "VARIABLES") return variableDirectory();
        if (s == "COPY") {
            SyntaxCondition e("93.970", "COPY method is not supported for object a RexxContext", false);
            e.substitutions.push_back(Value::string("a RexxContext"));
            throw e;
        }
        if (s == "STACKFRAMES" || s == "INVOCATION" || s == "THREAD" || s == "INTERPRETER")
            throw SyntaxCondition("98.900", ".CONTEXT~" + s + " is not available in compiled code", false);
        return ObjectDispatch::sendMessage(s, a);
    }
    // the method object of the class (what SELF~CLASS~METHOD finds), or the package's routine
    Value executable() {
        RexxThreadContext *t = rxobj::need();
        if (method) {
            void *cls = rxobj::findClass(scopeClass);
            if (!cls) return nil();
            Value c = EnvObject::adopt(cls);
            MessageResult m = classSide ? c.object->sendMessage("CLASS", {}) : MessageResult(c);
            if (!m) return nil();
            MessageResult found = m->object->sendMessage(classSide ? "INSTANCEMETHOD" : "METHOD", {Value::string(selector)});
            return found ? *found : nil();
        }
        if (rxobj::libraryPackage() == NULLOBJECT) return nil();
        Value pkg = Value::fromObject(std::make_shared<EnvObject>((void *)rxobj::pinRef(t, rxobj::libraryPackage())));
        MessageResult found = pkg.object->sendMessage("FINDROUTINE", {Value::string(selector)});
        return found ? *found : nil();
    }
    // RexxActivation::getAllLocalVariables: a Directory of the variables (a stem by its Stem object), SELF and SUPER
    Value variableDirectory() {
        MessageResult d = envClass("DIRECTORY").object->sendMessage("NEW", {});
        if (!d) throw std::runtime_error("cannot create a directory");
        for (const auto &entry : variables) d->object->sendMessage("PUT", {entry.second, Value::string(entry.first)});
        if (method) {
            d->object->sendMessage("PUT", {self, Value::string("SELF")});
            if (void *cls = rxobj::findClass(scopeClass)) {
                Value c = EnvObject::adopt(cls);
                if (MessageResult super = c.object->sendMessage("SUPERCLASS", {})) d->object->sendMessage("PUT", {*super, Value::string("SUPER")});
            }
        }
        return *d;
    }
};
inline Value activationContext(Variables &vars, const std::vector<std::optional<Value>> &arguments, std::size_t line,
                               const std::string &name, const char *scopeClass, const char *selector, bool classSide,
                               bool withVariables) {
    auto c = std::make_shared<ActivationContext>();
    c->numeric = vars.numeric;
    c->args = arguments;
    if (ActivationScope *a = ActivationScope::current()) {
        if (a->traps && a->traps->has) c->condition = Value::fromObject(a->traps->object);
        if (a->returnStatus) c->returnStatus = Value::number(std::to_string(*a->returnStatus));
    }
    c->line = Value::number(std::to_string(line));
    c->name = name;
    c->scopeClass = scopeClass;
    c->selector = selector;
    c->method = *scopeClass != '\0';
    c->classSide = classSide;
    if (c->method) c->self = selfObject();
    if (withVariables) {
        std::unordered_set<std::string> stems;
        forEachVariable(vars, [&](const std::string &name, const Value &value) {
            const std::size_t dot = name.find('.');
            if (dot == std::string::npos) c->variables.emplace_back(name, value);
            else stems.insert(name.substr(0, dot + 1));
        });
        vars.exposed.any([&](const char *e, std::size_t len) {
            const std::string n(e, len);
            if (!n.empty() && n.back() == '.') stems.insert(n);
            else if (const Value *v = lookup(vars, n)) c->variables.emplace_back(n, *v);
            return false;
        });
        for (const std::string &st : stems) c->variables.emplace_back(st, stemArg(vars, st));
    }
    return Value::fromObject(c);
}
// The method's own argument list as an interpreter array (omitted arguments stay empty slots): FORWARD's default ARGUMENTS.
inline Value argumentArray(const std::vector<std::optional<Value>> &args) {
    Value array = envClass("ARRAY");
    MessageResult made = array.object->sendMessage("NEW", {Value::string(std::to_string(args.size()))});
    if (!made) throw std::runtime_error("cannot create argument array");
    for (std::size_t i = 0; i < args.size(); ++i)
        if (args[i]) made->object->sendMessage("PUT", {*args[i], Value::string(std::to_string(i + 1))});
    return *made;
}
#endif
// An omitted argument slot (CALL f(,x) / obj~m(,x)).
inline Value omittedArgument() { return Value::fromObject(std::make_shared<EnvObject>(nullptr)); }
// SELF inside a native method is the receiver, as the interpreter sees it.
inline Value selfObject() {
    if (selfObjectHook) if (auto v = selfObjectHook()) return *v;
    void *h = rxobj::selfHandle();
    if (!h) throw std::runtime_error("SELF is not available here");
    return EnvObject::adopt(h);
}
// An environment symbol (.NAME), resolved as PackageClass::findClass does. A class of this package, of a package it
// requires or of the REXX package is fixed once found (the interpreter keeps it in the RexxDotVariable); any other
// name is looked up every time (the package's LOCAL, .local, .environment). Each compiled site keeps its EnvName
// (RX_ENV): the value found is kept with the object it came from, so the same object again is the same value, with no
// conversion and no pin.
struct EnvName {
    std::string name;
    int state = 0;            // 0 not yet resolved, 1 fixed, 2 looked up each time
    Value value;
    void *last = nullptr;     // (2) the object `value` came from, pinned while kept
    // (2) the interpreter epoch (rx_api_epoch.hpp) when `value` was looked up: while it has not moved, nothing can have
    // changed the three directories, and `value` is the answer (an unknown name too: the empty `last`)
    unsigned long epoch = 0;
    bool unknown = false;
    explicit EnvName(std::string n) : name(std::move(n)), value(Value::string(std::string())) {}
};
inline EnvName &envName(const std::string &name) {
    static thread_local std::unordered_map<std::string, std::unique_ptr<EnvName>> *names =
        new std::unordered_map<std::string, std::unique_ptr<EnvName>>;   // (never destroyed: values outlive the interpreter)
    auto &slot = (*names)[name];
    if (!slot) slot = std::make_unique<EnvName>(name);
    return *slot;
}
#ifdef RX2CPP_HOST_API
// A condition the interpreter left pending (a SETMETHOD entry, an UNKNOWN method or a security manager that raised):
// raised in compiled code as the interpreter's, with its condition object.
[[noreturn]] inline void raisePending(RexxThreadContext *t, const std::string &what) {
    RexxDirectoryObject info = t->GetConditionInfo();
    RexxCondition cd; t->DecodeConditionInfo(info, &cd);
    const std::string code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
    const std::string text = (cd.message && t->IsString(cd.message)) ? t->ObjectToStringValue(cd.message) : "error in " + what;
    rxobj::keepCondition(t);
    t->ClearCondition();
    rxobj::captureAdditional(t, info);
    SyntaxCondition raised(code, text, false);
    for (const std::string &a : rxobj::lastAdditional()) raised.substitutions.push_back(Value::string(a));
    raised.conditionObject = takeKeptCondition();
    throw raised;
}
// SecurityManager::callSecurityManager: the message (LOCAL, ENVIRONMENT, STREAM, ...) sent to the manager with its
// Directory of arguments; a result is required (91.999) and must be exactly 0 or 1 (34.903): true, the manager
// handled it (its answer in the RESULT entry).
inline bool askSecurityManager(RexxThreadContext *t, RexxObjectPtr manager, const char *what, RexxDirectoryObject args) {
    std::vector<rxobj::Arg> in(1); in[0].obj = (void *)args;
    rxobj::Result r; std::string code, text;
    struct Asking { bool saved; Asking() : saved(std::exchange(rxobj::securityCallInProgress(), true)) {} ~Asking() { rxobj::securityCallInProgress() = saved; } } asking;
    if (!rxobj::send((void *)manager, what, in, r, code, text)) {
        SyntaxCondition raised(code, text, false);
        for (const std::string &a : rxobj::lastAdditional()) raised.substitutions.push_back(Value::string(a));
        raised.conditionObject = takeKeptCondition();
        throw raised;
    }
    if (r.kind == 0) {
        SyntaxCondition missing("91.999", std::string("Message \"") + what + "\" did not return a result.", false);
        missing.substitutions.push_back(Value::string(what));
        throw missing;
    }
    std::string answer = r.bytes;
    if (r.kind == 2) { answer = t->ObjectToStringValue((RexxObjectPtr)r.obj); rxobj::release(r.obj); }
    if (answer != "0" && answer != "1") {
        SyntaxCondition bad("34.903", "Authorization return value must be exactly \"0\" or \"1\"; found \"" + answer + "\".", false);
        bad.substitutions.push_back(Value::string(answer));
        throw bad;
    }
    return answer == "1";
}
inline RexxObjectPtr securityResult(RexxThreadContext *t, RexxDirectoryObject args) {
    RexxObjectPtr result = t->DirectoryAt(args, "RESULT");
    if (t->CheckCondition()) raisePending(t, "AT");
    return result;
}
// PackageClass::findClass's search for a name that is not a class, with the package's security manager (manager; secured
// -1: its fields were not found, so the package answers it: PackageClass~findClass): the package LOCAL, the manager's
// LOCAL, .local, its ENVIRONMENT, .environment. SecurityManager::callSecurityManager: LOCAL / ENVIRONMENT sent with a
// Directory holding NAME; a result is required and must be exactly 0 or 1; 1 answers the RESULT entry (none: the
// search goes on). found: the answer is an entry whose value is .nil (the object answered is then NULLOBJECT).
inline RexxObjectPtr securedEnvironmentLookup(RexxThreadContext *t, const std::string &name, int secured, RexxObjectPtr manager, bool &found) {
    found = false;
    if (secured < 0) {
        // (only an entry that is .nil and no entry at all both answer .nil here: .nil it is when a directory has the name)
        RexxObjectPtr r = t->SendMessage1(rxobj::libraryPackage(), "FINDCLASS", (RexxObjectPtr)t->String(name.c_str()));
        if (t->CheckCondition()) raisePending(t, "FINDCLASS");
        if (r != NULLOBJECT && r != t->Nil()) return r;
        rxobj::EnvDirs &d = rxobj::findEnvDirs(t);
        for (RexxDirectoryObject dir : {d.pkg, d.local, d.global}) {
            if (dir == NULLOBJECT) continue;
            RexxObjectPtr has = t->SendMessage1((RexxObjectPtr)dir, "HASINDEX", (RexxObjectPtr)t->String(name.c_str()));
            if (t->CheckCondition()) raisePending(t, "HASINDEX");
            if (has != NULLOBJECT && t->IsString(has) && std::string(t->ObjectToStringValue(has)) == "1") { found = true; break; }
        }
        return NULLOBJECT;
    }
    rxobj::EnvDirs &d = rxobj::findEnvDirs(t);
    auto get = [&](RexxDirectoryObject dir) -> RexxObjectPtr {
        if (dir == NULLOBJECT) return NULLOBJECT;
        RexxObjectPtr o = t->DirectoryAt(dir, name.c_str());
        if (t->CheckCondition()) raisePending(t, "AT");
        return o;
    };
    auto ask = [&](const char *what) -> RexxObjectPtr {
        RexxDirectoryObject args = t->NewDirectory();
        t->DirectoryPut(args, (RexxObjectPtr)t->String(name.c_str()), "NAME");
        return askSecurityManager(t, manager, what, args) ? securityResult(t, args) : NULLOBJECT;
    };
    RexxObjectPtr o = get(d.pkg);
    if (o == NULLOBJECT && manager != NULLOBJECT) o = ask("LOCAL");
    if (o == NULLOBJECT) o = get(d.local);
    if (o == NULLOBJECT && manager != NULLOBJECT) o = ask("ENVIRONMENT");
    if (o == NULLOBJECT) o = get(d.global);
    return o;
}
#endif
// An environment symbol's value (PackageClass::findClass), or none when no source has it (the symbol is then a
// special name's value, or its own name).
inline std::optional<Value> envFind(EnvName &e) {
    if (e.state == 1) return e.value;
    const std::string &name = e.name;
    if (e.state == 0) {
        if (packageClassHook) if (auto v = packageClassHook(name)) { e.value = *v; e.state = 1; return e.value; }
#ifdef RX2CPP_HOST_API
        // (.LOCAL and .ENVIRONMENT are entries of .environment, found as any other: a security manager is asked for them
        // too, as interpreted)
        void *h = rxobj::packageClass(name);
#else
        void *h = (rx::eqLit(name, "LOCAL") || rx::eqLit(name, "ENVIRONMENT")) ? rxobj::environmentObject(name) : rxobj::findClass(name);
#endif
        if (h) { e.value = Value::fromObject(std::make_shared<EnvObject>(h)); e.state = 1; return e.value; }
        e.state = 2;
    }
#ifdef RX2CPP_HOST_API
    if (e.epoch != 0 && e.epoch == rxobj::interpreterEpoch()) {
        rxobj::bifStat("environment symbol kept (epoch)");
        if (e.unknown) return std::nullopt;
        return e.value;
    }
    RexxThreadContext *t = rxobj::need();
    // Kept only when the three directories answer this name from their entries (rxobj::environmentEntriesOnly, asked before the
    // lookup: no SETMETHOD entry or UNKNOWN method, whose value is computed at each read) and the package has no
    // security manager (asked at every lookup, as interpreted). The lookup's calls then run no Rexx code (DirectoryAt
    // of entries, below the string value of a String and the pin table): the epoch read after them is the one the
    // answer belongs to.
    RexxObjectPtr manager = NULLOBJECT;
    const int secured = rxobj::packageSecurityManager(t, rxobj::libraryPackage(), manager);
    const bool keep = secured == 0 && rxobj::environmentEntriesOnly(t, name);
    // (kept: the lookup below runs no Rexx code, so it does not move the epoch either; otherwise every miss would throw
    // away the values other symbols keep, and interleaved symbols would never be answered from the cache)
    std::optional<rxobj::QuietEpoch> quiet;
    if (keep) quiet.emplace();
    rxobj::bifStat(keep ? "environment symbol looked up (kept after)" : "environment symbol looked up (not kept)");
    bool found = false;
    RexxObjectPtr o = secured == 0 ? rxobj::environmentLookup(t, name) : securedEnvironmentLookup(t, name, secured, manager, found);
    if (secured == 0 && t->CheckCondition()) raisePending(t, "AT");
    if (found && o == NULLOBJECT) { e.epoch = 0; e.unknown = false; e.value = nil(); return e.value; }   // (an entry that is .nil)
    auto remember = [&]() { e.epoch = keep ? rxobj::interpreterEpoch() : 0; };
    if (o == NULLOBJECT) { e.unknown = true; remember(); return std::nullopt; }
    e.unknown = false;
    if ((void *)o == e.last) { t->ReleaseLocalReference(o); remember(); return e.value; }
    Value v = Value::string(std::string());
    if (rxobj::isPlainString(t, o)) {
        // A String entry (.local~v1 = 'a') is a string value in compiled code, as strings are everywhere.
        RexxStringObject so = (RexxStringObject)t->ObjectToString(o);
        v = Value::string(std::string(t->StringData(so), t->StringLength(so)));
        if ((RexxObjectPtr)so != o) t->ReleaseLocalReference((RexxObjectPtr)so);
    }
    else v = Value::fromObject(std::make_shared<EnvObject>((void *)rxobj::pinRef(t, o)));
    void *kept = (void *)rxobj::pinRef(t, o);
    if (e.last) rxobj::unpinRef(t, e.last);
    e.last = kept;
    e.value = v;
    t->ReleaseLocalReference(o);
    e.epoch = keep ? rxobj::interpreterEpoch() : 0;
    return v;
#else
    if (void *entry = rxobj::environmentEntry(name)) return Value::fromObject(std::make_shared<EnvObject>(entry));
    return std::nullopt;
#endif
}
// An unknown environment symbol is its own name (.FOO).
inline Value envValue(EnvName &e) {
    if (e.state == 1) return e.value;
    if (auto v = envFind(e)) return std::move(*v);
    return Value::string("." + e.name);
}
// .RS .LINE .CONTEXT .METHODS .RESOURCES .ROUTINES: an environment symbol first, as any (RexxDotVariable::evaluate:
// resolveDotVariable, which asks a security manager too), the activation's special value when no source has it.
template <class F> inline Value envOrSpecial(EnvName &e, F &&special) {
    if (auto v = envFind(e)) return std::move(*v);
    return special();
}
// One environment symbol of the compiled code: its EnvName found once per site and thread.
#define RX_ENV(N) ([]() -> ::rx::Value { static thread_local ::rx::EnvName *_rxE = nullptr; if (!_rxE) _rxE = &::rx::envName(N); return ::rx::envValue(*_rxE); }())
// A special name (.RS, .LINE, ...): the environment symbol of that name first, else SPECIAL (an expression).
#define RX_ENV_SPECIAL(N, ...) ([&]() -> ::rx::Value { static thread_local ::rx::EnvName *_rxE = nullptr; if (!_rxE) _rxE = &::rx::envName(N); return ::rx::envOrSpecial(*_rxE, [&]() -> ::rx::Value { return __VA_ARGS__; }); }())
// .NAME environment symbols resolve to the interpreter's own classes (.ARRAY, .DIRECTORY, .LIST, ...).
inline Value envClass(const std::string &name) { return envValue(envName(name)); }
#ifdef RX2CPP_HOST_API
// .MUTABLEBUFFER in compiled library code. A buffer built and read by compiled code (json.cls: one APPEND per token)
// stays native: APPEND of plain strings, STRING, MAKESTRING and LENGTH run here without crossing to the interpreter.
// Any other message, or handing the buffer to the interpreter, creates the interpreter's own MutableBuffer with the
// same content; from then on this object forwards everything to it, so there is one object with one identity.
struct NativeMutableBuffer final : NativeRefBase, std::enable_shared_from_this<NativeMutableBuffer> {
    std::string data;
    std::optional<Value> real;   // the interpreter MutableBuffer, once created
    explicit NativeMutableBuffer(std::string initial) : data(std::move(initial)) {}
    Value &promote() {
        if (!real) {
            MessageResult made = envClass("MUTABLEBUFFER").object->sendMessage("NEW", {Value::string(data)});
            if (!made || !made->isObject()) throw std::runtime_error(".MutableBuffer~new returned no object");
            real = *made;
            std::string().swap(data);
        }
        return *real;
    }
    void *materialize() override {
        auto *env = dynamic_cast<EnvObject *>(promote().object.get());
        if (!env) throw std::runtime_error("MutableBuffer is not an interpreter object");
        return env->handle;
    }
    static bool plain(const std::vector<Value> &args) {
        for (const Value &a : args) if (a.isObject()) return false;
        return true;
    }
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override {
        if (!real) {
            if (rx::eqLit(selector, "APPEND") && !args.empty() && plain(args)) {
                for (const Value &a : args) data.append(a.bytes.data(), a.bytes.size());
                return Value::fromObject(shared_from_this());
            }
            if ((rx::eqLit(selector, "STRING") || rx::eqLit(selector, "MAKESTRING")) && args.empty()) return Value::string(data);
            if (rx::eqLit(selector, "LENGTH") && args.empty()) return Value::string(std::to_string(data.size()));
        }
        return promote().object->sendMessage(selector, args);
    }
    Value sendBinary(const std::string &selector, const Value &rhs) override {
        return promote().object->sendBinary(selector, rhs);
    }
    Value sendUnary(const std::string &selector) override { return promote().object->sendUnary(selector); }
    std::string display() const override {
        if (!real) return data;
        MessageResult text = real->object->sendMessage("STRING", {});
        return text ? text->bytes.str() : std::string();
    }
};
// The .MUTABLEBUFFER class: NEW with plain-string arguments makes a NativeMutableBuffer; everything else is the
// interpreter's class (which is also what the interpreter receives for it).
struct NativeMutableBufferClass final : NativeRefBase {
    static Value interpreterClass() { return envClass("MUTABLEBUFFER"); }
    void *materialize() override {
        auto *env = dynamic_cast<EnvObject *>(interpreterClass().object.get());
        if (!env) throw std::runtime_error(".MutableBuffer is not an interpreter class");
        return env->handle;
    }
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override {
        // NEW([string] [, buffersize]): the initial content; the size is only a capacity hint.
        if (rx::eqLit(selector, "NEW") && args.size() <= 2 && NativeMutableBuffer::plain(args)) {
            if (args.size() == 2) {
                const std::string &n = args[1].bytes;
                if (n.empty() || n.find_first_not_of("0123456789") != std::string::npos)
                    return interpreterClass().object->sendMessage(selector, args);   // let the interpreter raise its error
            }
            auto buffer = std::make_shared<NativeMutableBuffer>(args.empty() ? std::string() : args[0].bytes.str());
            if (args.size() == 2) {
                const std::string &n = args[1].bytes;
                buffer->data.reserve(n.size() > 8 ? std::size_t(1) << 26 : std::min<std::size_t>(std::stoull(n), std::size_t(1) << 26));
            }
            return Value::fromObject(buffer);
        }
        return interpreterClass().object->sendMessage(selector, args);
    }
    Value sendBinary(const std::string &selector, const Value &rhs) override {
        return interpreterClass().object->sendBinary(selector, rhs);
    }
    std::string display() const override { return "The MutableBuffer class"; }
};
inline Value mutableBufferClass() {
    static thread_local const Value c = Value::fromObject(std::make_shared<NativeMutableBufferClass>());
    return c;
}
// .ARRAY in compiled library code (single dimension). Native while it stays in compiled code: [] []= AT PUT APPEND
// ITEMS SIZE FIRST LAST FIRSTITEM LASTITEM ISEMPTY HASINDEX REMOVE MAKEARRAY ALLITEMS ALLINDEXES ISA CLASS and the
// identity comparisons. Any other message, an index that is not a plain positive whole number, or leaving compiled
// code creates the interpreter's own Array with the same slots and size; from then on this object forwards to it.
// SIZE follows the interpreter: the larger of the NEW size and the highest index used; APPEND uses last item + 1.
struct NativeArrayClass;
inline Value nativeArrayClass();
struct NativeArray final : NativeRefBase, ItemSnapshot, std::enable_shared_from_this<NativeArray> {
    std::vector<std::optional<Value>> slots;   // slots.size() is the Array's SIZE
    std::size_t count = 0;                      // ITEMS
    std::optional<Value> real;
    static constexpr std::size_t maxSlots = std::size_t(1) << 20;
    bool sized = true;                          // .array~new gives no dimension yet (DIMENSION 0); NEW(n) and OF give 1
    explicit NativeArray(std::size_t size = 0, bool withSize = true) : slots(size), sized(withSize) {}
    void gcValues(const std::function<void(const Value &)> &f) const override {
        for (const auto &v : slots) if (v) f(*v);
        if (real) f(*real);
    }
    void gcClear() override {
        std::vector<std::optional<Value>> gone; gone.swap(slots); count = 0;
        std::optional<Value> r; r.swap(real);
    }
    // A positive whole number written plainly (blanks around allowed); anything else is left to the interpreter.
    static bool index(const Value &v, std::size_t &out) {
        if (v.isObject()) return false;
        // its numeric form when it is a plain whole number written in at most 9 characters (a number made by arithmetic
        // has no leading zeros: its characters are not needed)
        const std::uint32_t m = numMeta(v);
        if (m & NumCache::integer) {
            const std::int64_t c = v.bytes.numCache().coef.load(std::memory_order_relaxed);
            if (c <= 0) return false;
            if ((m & NumCache::pending) || v.bytes.size() <= 9) { out = static_cast<std::size_t>(c); return true; }
        }
        const std::string &s = v.bytes;
        std::size_t a = s.find_first_not_of(' '), b = s.find_last_not_of(' ');
        if (a == std::string::npos || b - a + 1 > 9) return false;
        std::size_t n = 0;
        for (std::size_t i = a; i <= b; ++i) {
            if (s[i] < '0' || s[i] > '9') return false;
            n = n * 10 + static_cast<std::size_t>(s[i] - '0');
        }
        if (n == 0) return false;
        out = n;
        return true;
    }
    static bool omitted(const Value &v) {
        auto *e = dynamic_cast<EnvObject *>(v.object.get());
        return e && e->handle == nullptr;
    }
    std::size_t lastIndex() const {
        for (std::size_t i = slots.size(); i > 0; --i) if (slots[i - 1]) return i;
        return 0;
    }
    // [] / []= with a plain index, as sendMessage answers them (rx::indexValue / indexAssign)
    bool indexAt(const Value &ix, const Value *&slot) override {
        std::size_t i = 0;
        if (real || !index(ix, i)) return false;
        slot = i <= slots.size() && slots[i - 1] ? &*slots[i - 1] : nullptr;
        return true;
    }
    bool indexPut(Value &v, const Value &ix) override {
        std::size_t i = 0;
        if (real || omitted(v) || !index(ix, i)) return false;
        if (i > slots.size()) {
            if (i > maxSlots) return false;
            slots.resize(i);
        }
        if (!slots[i - 1]) ++count;
        slots[i - 1] = std::move(v);
        return true;
    }
    bool place(std::size_t i, const Value &v) {      // false: too sparse to keep natively
        if (i > slots.size()) {
            if (i > maxSlots) return false;
            slots.resize(i);
        }
        if (!slots[i - 1]) ++count;
        slots[i - 1] = v;
        return true;
    }
    Value &promote() {
        if (!real) {
            std::vector<Value> values;
            std::vector<bool> holes;
            values.reserve(slots.size());
            for (const auto &s : slots) { values.push_back(s ? *s : Value::string(std::string())); holes.push_back(!s); }
            std::vector<rxobj::Arg> in; EnvObject::convert(values, in);
            for (std::size_t i = 0; i < in.size(); ++i) if (holes[i]) in[i].omitted = true;
            if (slots.empty() && sized) {   // an empty array with a dimension: .array~new(0) (the API's has none)
                MessageResult made = envClass("ARRAY").object->sendMessage("NEW", {Value::string("0")});
                if (!made) throw std::runtime_error("cannot create an array");
                real = *made;
            }
            else real = Value::fromObject(std::make_shared<EnvObject>(rxobj::newArray(slots.size(), in)));
            std::vector<std::optional<Value>>().swap(slots);
            count = 0;
        }
        return *real;
    }
    void *materialize() override { return static_cast<EnvObject *>(promote().object.get())->handle; }
    std::optional<std::vector<Value>> snapshotItems() override {
        if (real) return std::nullopt;
        std::vector<Value> items;
        items.reserve(count);
        for (const auto &s : slots) if (s) items.push_back(*s);
        return items;
    }
    Value self() { return Value::fromObject(shared_from_this()); }
    static Value number(std::size_t n) { return Value::string(std::to_string(n)); }
    Value newArrayOf(std::vector<Value> items) {
        auto a = std::make_shared<NativeArray>(items.size());
        for (std::size_t i = 0; i < items.size(); ++i) a->slots[i] = std::move(items[i]);
        a->count = items.size();
        return Value::fromObject(a);
    }
    MessageResult forward(const std::string &selector, const std::vector<Value> &args) {
        return promote().object->sendMessage(selector, args);
    }
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override;
    bool answer(const std::string &selector, const std::vector<Value> &args, MessageResult &result);
    Value sendBinary(const std::string &selector, const Value &rhs) override {
        if (!real && (rx::eqLit(selector, "==") || rx::eqLit(selector, "=") || rx::eqLit(selector, "\\==") || rx::eqLit(selector, "\\=") || rx::eqLit(selector, "<>") || rx::eqLit(selector, "><"))) {
            const bool same = rhs.isObject() && rhs.object.get() == this;
            const bool positive = rx::eqLit(selector, "==") || rx::eqLit(selector, "=");
            return Value::string(same == positive ? "1" : "0");
        }
        return promote().object->sendBinary(selector, rhs);
    }
    Value sendUnary(const std::string &selector) override { return promote().object->sendUnary(selector); }
    std::string display() const override {
        MessageResult text = const_cast<NativeArray *>(this)->forward("STRING", {});
        return text ? text->bytes.str() : std::string();
    }
};
// Object~SEND(name, args...) / SENDWITH(name, array) to a native class object: the message itself, sent to the same
// object (its own methods: a native class has no override of SEND), as RexxObject::sendWith does: the name
// upper-cased, the array's items up to its last one (messageArgCount), holes omitted. A name that is not a plain
// string (a scope override) or an interpreter array is left to the interpreter.
inline bool nativeSendWith(const std::string &s, const std::vector<Value> &a, std::string &sel, std::vector<Value> &args) {
    if (a.empty() || a[0].isObject()) return false;
    if (rx::eqLit(s, "SEND")) args.assign(a.begin() + 1, a.end());
    else if (rx::eqLit(s, "SENDWITH") && a.size() == 2 && a[1].isObject()) {
        auto *arr = dynamic_cast<NativeArray *>(a[1].object.get());
        if (!arr || arr->real) return false;
        std::size_t last = arr->slots.size();
        while (last > 0 && !arr->slots[last - 1]) --last;
        for (std::size_t i = 0; i < last; ++i) args.push_back(arr->slots[i] ? *arr->slots[i] : omittedArgument());
    }
    else return false;
    sel = a[0].bytes.str();
    for (char &c : sel) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
    return true;
}
struct NativeArrayClass final : NativeRefBase {
    static Value interpreterClass() { return envClass("ARRAY"); }
    void *materialize() override { return static_cast<EnvObject *>(interpreterClass().object.get())->handle; }
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override {
        { std::string sel; std::vector<Value> sent; if (nativeSendWith(selector, args, sel, sent)) return sendMessage(sel, sent); }
        if (rx::eqLit(selector, "NEW")) {
            std::size_t n = 0;
            if (args.empty()) return Value::fromObject(std::make_shared<NativeArray>(0, false));
            if (args.size() == 1 && !args[0].isObject()) {
                const std::string &s = args[0].bytes;
                const std::size_t a = s.find_first_not_of(' ');
                if (a != std::string::npos && s.substr(a, s.find_last_not_of(' ') - a + 1) == "0")
                    return Value::fromObject(std::make_shared<NativeArray>(0));
                if (NativeArray::index(args[0], n) && n <= NativeArray::maxSlots)
                    return Value::fromObject(std::make_shared<NativeArray>(n));
            }
        } else if (rx::eqLit(selector, "OF")) {
            auto a = std::make_shared<NativeArray>(args.size());
            for (std::size_t i = 0; i < args.size(); ++i) {
                if (NativeArray::omitted(args[i])) continue;
                a->slots[i] = args[i];
                ++a->count;
            }
            return Value::fromObject(a);
        }
        return interpreterClass().object->sendMessage(selector, args);
    }
    Value sendBinary(const std::string &selector, const Value &rhs) override {
        return interpreterClass().object->sendBinary(selector, rhs);
    }
    std::string display() const override { return "The Array class"; }
};
// .STEM in compiled library code: NEW gives a native StemObject (it becomes an interpreter stem when it crosses, or on a
// message it does not answer itself); any other message, and the class as an argument, is the interpreter's Stem class.
struct NativeStemClass final : NativeRefBase {
    static Value interpreterClass() { return envClass("STEM"); }
    void *materialize() override { return static_cast<EnvObject *>(interpreterClass().object.get())->handle; }
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override {
        { std::string sel; std::vector<Value> sent; if (nativeSendWith(selector, args, sel, sent)) return sendMessage(sel, sent); }
        if (rx::eqLit(selector, "NEW") && args.size() <= 1 && (args.empty() || !args[0].isObject()))
            return stemClass().object->sendMessage(selector, args);
        return interpreterClass().object->sendMessage(selector, args);
    }
    Value sendBinary(const std::string &selector, const Value &rhs) override {
        return interpreterClass().object->sendBinary(selector, rhs);
    }
    std::string display() const override { return "The Stem class"; }
};
inline Value nativeStemClass() {
    static thread_local const Value c = Value::fromObject(std::make_shared<NativeStemClass>());
    return c;
}
inline Value nativeArrayClass() {
    static thread_local const Value c = Value::fromObject(std::make_shared<NativeArrayClass>());
    return c;
}
// .DIRECTORY in compiled library code. Native while it stays in compiled code: [] []= AT PUT HASINDEX ITEMS ISEMPTY ISA
// CLASS and the identity comparisons, with plain string indexes. Iteration order is the interpreter's hash order, which
// depends on insertion history: ALLINDEXES and ALLITEMS ask it of a scratch interpreter Directory given the same keys
// in the same order (the same history gives the same table; the values play no part), and answer native arrays of the
// native entries in that order. Anything else that shows order (MAKEARRAY, SUPPLIER, DO OVER, ...), REMOVE, any other
// message, or leaving compiled code creates the interpreter's Directory by replaying the first insertions in their
// original order and forwards to it from then on.
struct NativeDirectoryClass;
inline Value nativeDirectoryClass();
inline Value nativeStringTableClass();
struct NativeDirectory final : NativeRefBase, std::enable_shared_from_this<NativeDirectory> {
    // DIRECTORY, or STRINGTABLE (the same string-keyed collection, StringHashCollection, without SETMETHOD entries)
    const char *kind = "DIRECTORY";
    NativeDirectory() = default;
    explicit NativeDirectory(const char *k) : kind(k) {}
    Value classValue() const { return kind[0] == 'D' ? nativeDirectoryClass() : nativeStringTableClass(); }
    std::vector<std::string> order;                       // first-insertion order
    std::unordered_map<std::string, Value> entries;
    std::optional<Value> real;
    std::vector<std::size_t> hashOrder;                   // positions in order, in the interpreter's order (when asked)
    void gcValues(const std::function<void(const Value &)> &f) const override {
        for (const auto &kv : entries) f(kv.second);
        if (real) f(*real);
    }
    void gcClear() override {
        std::unordered_map<std::string, Value> gone; gone.swap(entries);
        order.clear(); hashOrder.clear();
        std::optional<Value> r; r.swap(real);
    }
    // The interpreter's ALLINDEXES order of these keys (no entry is ever removed while native: a new key is what makes
    // it stale).
    const std::vector<std::size_t> &interpreterOrder() {
        if (hashOrder.size() == order.size()) return hashOrder;
        MessageResult made = envClass(kind).object->sendMessage("NEW", {});
        auto *env = made && made->isObject() ? dynamic_cast<EnvObject *>(made->object.get()) : nullptr;
        if (!env) throw std::runtime_error(".Directory~new is not an interpreter object");
        std::vector<rxobj::Arg> in(order.size());
        rxobj::directoryPutAll(env->handle, order, in, kind[0] == 'D');   // (empty strings: only the keys matter)
        std::unordered_map<std::string, std::size_t> position;
        for (std::size_t i = 0; i < order.size(); ++i) position.emplace(order[i], i);
        RexxThreadContext *t = rxobj::need();
        rxobj::LocalRefs temps(t);
        RexxObjectPtr indexes = temps(t->SendMessage0((RexxObjectPtr)env->handle, "ALLINDEXES"));
        if (indexes == NULLOBJECT || t->CheckCondition() || !t->IsArray(indexes)) throw std::runtime_error("Directory ALLINDEXES failed");
        const std::size_t count = t->ArrayItems((RexxArrayObject)indexes);
        std::vector<std::size_t> out;
        out.reserve(count);
        for (std::size_t i = 1; i <= count; ++i) {
            RexxStringObject s = t->ObjectToString(temps(t->ArrayAt((RexxArrayObject)indexes, i)));
            temps((RexxObjectPtr)s);
            auto it = position.find(std::string(t->StringData(s), t->StringLength(s)));
            if (it == position.end()) throw std::runtime_error("Directory ALLINDEXES: unknown index");
            out.push_back(it->second);
        }
        if (out.size() != order.size()) throw std::runtime_error("Directory ALLINDEXES: wrong count");
        hashOrder = std::move(out);
        return hashOrder;
    }
    static Value arrayOf(std::vector<Value> items) {
        auto a = std::make_shared<NativeArray>(items.size());
        for (std::size_t i = 0; i < items.size(); ++i) a->slots[i] = std::move(items[i]);
        a->count = items.size();
        return Value::fromObject(a);
    }
    Value &promote() {
        if (!real) {
            MessageResult made = envClass(kind).object->sendMessage("NEW", {});
            if (!made || !made->isObject()) throw std::runtime_error(".Directory~new returned no object");
            auto *env = dynamic_cast<EnvObject *>(made->object.get());
            if (!env) throw std::runtime_error(".Directory~new is not an interpreter object");
            std::vector<Value> values;
            values.reserve(order.size());
            for (const auto &k : order) values.push_back(entries.at(k));
            std::vector<rxobj::Arg> in; EnvObject::convert(values, in);
            rxobj::directoryPutAll(env->handle, order, in, kind[0] == 'D');
            real = *made;
            std::vector<std::string>().swap(order);
            std::unordered_map<std::string, Value>().swap(entries);
        }
        return *real;
    }
    void *materialize() override { return static_cast<EnvObject *>(promote().object.get())->handle; }
    // Whether a Directory understands the selector itself (a method of Directory or an ancestor), asked once per
    // selector of an interpreter Directory kept for the purpose.
    static bool directoryMethod(const char *kind, const std::string &selector) {
        static std::mutex gate;
        static std::unordered_map<std::string, bool> known;   // kind:selector
        static std::unordered_map<std::string, Value> probes;
        std::lock_guard<std::mutex> g(gate);
        const std::string key = std::string(kind) + ':' + selector;
        auto it = known.find(key);
        if (it != known.end()) return it->second;
        auto p = probes.find(kind);
        if (p == probes.end()) {
            MessageResult made = envClass(kind).object->sendMessage("NEW", {});
            if (!made) return true;
            p = probes.emplace(kind, *made).first;
        }
        MessageResult has = p->second.object->sendMessage("HASMETHOD", {Value::string(selector)});
        const bool yes = !has || has->isObject() || has->bytes.str() != "0";
        known.emplace(key, yes);
        return yes;
    }
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override {
        if (real) return real->object->sendMessage(selector, args);
        const std::size_t n = args.size();
        const bool key0 = n >= 1 && !args[n == 2 ? 1 : 0].isObject();
        if ((rx::eqLit(selector, "[]") || rx::eqLit(selector, "AT")) && n == 1 && key0) {
            auto it = entries.find(args[0].bytes);
            return it == entries.end() ? nil() : it->second;
        }
        if ((rx::eqLit(selector, "[]=") || rx::eqLit(selector, "PUT")) && n == 2 && key0 && !NativeArray::omitted(args[0])) {
            const std::string &k = args[1].bytes;
            auto it = entries.find(k);
            if (it == entries.end()) { order.push_back(k); entries.emplace(k, args[0]); }
            else it->second = args[0];
            return std::nullopt;
        }
        if (rx::eqLit(selector, "HASINDEX") && n == 1 && key0) return Value::string(entries.count(args[0].bytes) ? "1" : "0");
        // DirectoryClass::unknown: a message that is no Directory method names an entry: NAME= sets it, NAME answers
        // it (.nil when absent). (d~w1 = x; d~w1)
        if (!selector.empty() && ((n == 0 && selector.back() != '=') || (n == 1 && selector.size() > 1 && selector.back() == '=' &&
                                  !NativeArray::omitted(args[0]))) && !directoryMethod(kind, selector)) {
            if (n == 0) {
                auto it = entries.find(selector);
                return it == entries.end() ? nil() : it->second;
            }
            const std::string k = selector.substr(0, selector.size() - 1);
            auto it = entries.find(k);
            if (it == entries.end()) { order.push_back(k); entries.emplace(k, args[0]); }
            else it->second = args[0];
            return std::nullopt;
        }
        if (rx::eqLit(selector, "ITEMS") && n == 0) return Value::string(std::to_string(entries.size()));
        if (rx::eqLit(selector, "ISEMPTY") && n == 0) return Value::string(entries.empty() ? "1" : "0");
        if ((rx::eqLit(selector, "ALLINDEXES") || rx::eqLit(selector, "ALLITEMS")) && n == 0) {
            const std::vector<std::size_t> &at = interpreterOrder();
            std::vector<Value> items;
            items.reserve(at.size());
            for (std::size_t i : at) items.push_back(rx::eqLit(selector, "ALLINDEXES") ? Value::string(order[i]) : entries.at(order[i]));
            return arrayOf(std::move(items));
        }
        if (rx::eqLit(selector, "CLASS") && n == 0) return classValue();
        if (rx::eqLit(selector, "ISA") && n == 1 && args[0].isObject()) {
            if (args[0].object.get() == classValue().object.get()) return Value::string("1");
            Value cls = envClass(kind);
            if (auto *e = dynamic_cast<EnvObject *>(args[0].object.get()))
                if (e->handle == static_cast<EnvObject *>(cls.object.get())->handle) return Value::string("1");
            return cls.object->sendMessage("ISSUBCLASSOF", args);
        }
        return promote().object->sendMessage(selector, args);
    }
    Value sendBinary(const std::string &selector, const Value &rhs) override {
        if (!real && (rx::eqLit(selector, "==") || rx::eqLit(selector, "=") || rx::eqLit(selector, "\\==") || rx::eqLit(selector, "\\=") || rx::eqLit(selector, "<>") || rx::eqLit(selector, "><"))) {
            const bool same = rhs.isObject() && rhs.object.get() == this;
            const bool positive = rx::eqLit(selector, "==") || rx::eqLit(selector, "=");
            return Value::string(same == positive ? "1" : "0");
        }
        return promote().object->sendBinary(selector, rhs);
    }
    Value sendUnary(const std::string &selector) override { return promote().object->sendUnary(selector); }
    std::string display() const override {
        MessageResult text = const_cast<NativeDirectory *>(this)->promote().object->sendMessage("STRING", {});
        return text ? text->bytes.str() : std::string();
    }
};
struct NativeDirectoryClass final : NativeRefBase {
    const char *kind;
    explicit NativeDirectoryClass(const char *k) : kind(k) {}
    void *materialize() override { return static_cast<EnvObject *>(envClass(kind).object.get())->handle; }
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override {
        { std::string sel; std::vector<Value> sent; if (nativeSendWith(selector, args, sel, sent)) return sendMessage(sel, sent); }
        // Only ~new without arguments: an initial size changes the interpreter's table layout (and order).
        if (rx::eqLit(selector, "NEW") && args.empty()) return Value::fromObject(std::make_shared<NativeDirectory>(kind));
        // MapCollection OF (CoreClasses.orx): a new collection, then for each argument, an array of exactly two items
        // (index, item), PUT(item, index). Native when every argument is a native array of two items whose index is a
        // string; anything else (and every error) is the interpreter's.
        if (rx::eqLit(selector, "OF")) {
            bool plain = true;
            for (const Value &a : args) {
                auto *pair = a.isObject() ? dynamic_cast<NativeArray *>(a.object.get()) : nullptr;
                if (!pair || pair->real || pair->count != 2 || pair->slots.size() < 2 || !pair->slots[0] || !pair->slots[1] ||
                    pair->slots[0]->isObject()) { plain = false; break; }
            }
            if (plain) {
                auto made = std::make_shared<NativeDirectory>(kind);
                for (const Value &a : args) {
                    auto *pair = static_cast<NativeArray *>(a.object.get());
                    made->sendMessage("PUT", {*pair->slots[1], *pair->slots[0]});
                }
                return Value::fromObject(made);
            }
        }
        return envClass(kind).object->sendMessage(selector, args);
    }
    Value sendBinary(const std::string &selector, const Value &rhs) override {
        return envClass(kind).object->sendBinary(selector, rhs);
    }
    std::string display() const override { return kind[0] == 'D' ? "The Directory class" : "The StringTable class"; }
};
inline Value nativeDirectoryClass() {
    static thread_local const Value c = Value::fromObject(std::make_shared<NativeDirectoryClass>("DIRECTORY"));
    return c;
}
inline Value nativeStringTableClass() {
    static thread_local const Value c = Value::fromObject(std::make_shared<NativeDirectoryClass>("STRINGTABLE"));
    return c;
}
inline MessageResult NativeArray::sendMessage(const std::string &selector, const std::vector<Value> &args) {
    if (real) return real->object->sendMessage(selector, args);
    MessageResult out;
    if (answer(selector, args, out)) return out;
    return forward(selector, args);
}
// The messages answered natively (false: the interpreter's Array must answer it). The array part of an instance of a
// compiled .Array subclass (InstanceState::builtin) asks this too, so nothing here may answer with the array itself
// or its class: FILL, CLASS and ISA are the caller's to leave out.
inline bool NativeArray::answer(const std::string &selector, const std::vector<Value> &args, MessageResult &result) {
    std::size_t i = 0;
    const std::size_t n = args.size();
    switch (selector.empty() ? 0 : selector[0]) {
    case '[':
        if (rx::eqLit(selector, "[]") && n == 1 && index(args[0], i))
            { result = i <= slots.size() && slots[i - 1] ? *slots[i - 1] : nil(); return true; }
        if (rx::eqLit(selector, "[]=") && n == 2 && !omitted(args[0]) && index(args[1], i) && place(i, args[0])) { result = std::nullopt; return true; }
        break;
    case 'A':
        if (rx::eqLit(selector, "AT") && n == 1 && index(args[0], i))
            { result = i <= slots.size() && slots[i - 1] ? *slots[i - 1] : nil(); return true; }
        if (rx::eqLit(selector, "APPEND") && n == 1 && !omitted(args[0])) {
            const std::size_t at = lastIndex() + 1;
            if (place(at, args[0])) { result = number(at); return true; }
        }
        if (rx::eqLit(selector, "ALLITEMS") && n == 0) { result = newArrayOf(*snapshotItems()); return true; }
        if (rx::eqLit(selector, "ALLINDEXES") && n == 0) {
            std::vector<Value> ix;
            for (std::size_t k = 0; k < slots.size(); ++k) if (slots[k]) ix.push_back(number(k + 1));
            result = newArrayOf(std::move(ix));
            return true;
        }
        break;
    case 'C':
        if (rx::eqLit(selector, "CLASS") && n == 0) { result = nativeArrayClass(); return true; }
        break;
    case 'D':
        // ArrayClass::deleteRexx / deleteItem / closeGap: past the size, .nil and no change; otherwise the item there
        // (or .nil) is taken out and every later slot moves down one (the size one less)
        if (rx::eqLit(selector, "DELETE") && n == 1 && index(args[0], i)) {
            if (i > slots.size()) { result = nil(); return true; }
            std::optional<Value> out = std::move(slots[i - 1]);
            slots.erase(slots.begin() + static_cast<std::ptrdiff_t>(i - 1));
            if (out) --count;
            result = out ? std::move(*out) : nil();
            return true;
        }
        break;
    case 'F':
        // ArrayClass::fillRexx: every slot of the array's size, the receiver back
        if (rx::eqLit(selector, "FILL") && n == 1 && !omitted(args[0])) {
            for (auto &s : slots) s = args[0];
            count = slots.size();
            result = self();
            return true;
        }
        if (rx::eqLit(selector, "FIRST") && n == 0) {
            for (std::size_t k = 0; k < slots.size(); ++k) if (slots[k]) { result = number(k + 1); return true; }
            { result = nil(); return true; }
        }
        if (rx::eqLit(selector, "FIRSTITEM") && n == 0) {
            for (const auto &s : slots) if (s) { result = *s; return true; }
            { result = nil(); return true; }
        }
        break;
    case 'H':
        if (rx::eqLit(selector, "HASINDEX") && n == 1 && index(args[0], i))
            { result = Value::string(i <= slots.size() && slots[i - 1] ? "1" : "0"); return true; }
        break;
    case 'I':
        if (rx::eqLit(selector, "ITEMS") && n == 0) { result = number(count); return true; }
        if (rx::eqLit(selector, "ISEMPTY") && n == 0) { result = Value::string(count == 0 ? "1" : "0"); return true; }
        if (rx::eqLit(selector, "ISA") && n == 1 && args[0].isObject()) {
            if (dynamic_cast<NativeArrayClass *>(args[0].object.get())) { result = Value::string("1"); return true; }
            // An Array instance: isA(c) is c == .Array or .Array~isSubclassOf(c) (no promotion needed).
            Value cls = NativeArrayClass::interpreterClass();
            if (auto *e = dynamic_cast<EnvObject *>(args[0].object.get()))
                if (e->handle == static_cast<EnvObject *>(cls.object.get())->handle) { result = Value::string("1"); return true; }
            result = cls.object->sendMessage("ISSUBCLASSOF", args);
            return true;
        }
        break;
    case 'L':
        if (rx::eqLit(selector, "LAST") && n == 0) { const std::size_t l = lastIndex(); result = l ? number(l) : nil(); return true; }
        if (rx::eqLit(selector, "LASTITEM") && n == 0) { const std::size_t l = lastIndex(); result = l ? *slots[l - 1] : nil(); return true; }
        break;
    case 'M':
        if (rx::eqLit(selector, "MAKEARRAY") && n == 0) { result = newArrayOf(*snapshotItems()); return true; }
        break;
    case 'P':
        if (rx::eqLit(selector, "PUT") && n == 2 && !omitted(args[0]) && index(args[1], i) && place(i, args[0])) { result = std::nullopt; return true; }
        break;
    case 'R':
        if (rx::eqLit(selector, "REMOVE") && n == 1 && index(args[0], i)) {
            if (i > slots.size() || !slots[i - 1]) { result = nil(); return true; }
            Value out = std::move(*slots[i - 1]);
            slots[i - 1].reset();
            --count;
            result = std::move(out);
            return true;
        }
        break;
    case 'S':
        if (rx::eqLit(selector, "SIZE") && n == 0) { result = number(slots.size()); return true; }
        break;
    default: break;
    }
    return false;
}
#endif
#ifdef RX2CPP_HOST_API
// A CALL of an external program merges the program's public routines and classes into the calling activation's package
// (RexxActivation::callExternalRexx: mergeRequired). The helper that made the call got them (its package): they go on
// to the library package, as a package of them added to it (PackageClass::addPackage merges the same way: new names
// only). merged: how many the helper had already passed on.
inline void mergeExternalCall(RexxThreadContext *t, RexxRoutineObject helper, std::size_t &merged) {
    if (rxobj::libraryPackage() == NULLOBJECT) return;
    rxobj::LocalRefs temps(t);
    RexxObjectPtr package = temps(t->SendMessage0((RexxObjectPtr)helper, "PACKAGE"));
    if (t->CheckCondition() || package == NULLOBJECT) { t->ClearCondition(); return; }
    RexxObjectPtr routines = temps(t->SendMessage0(package, "IMPORTEDROUTINES"));
    RexxObjectPtr classes = temps(t->SendMessage0(package, "IMPORTEDCLASSES"));
    if (t->CheckCondition() || routines == NULLOBJECT || classes == NULLOBJECT) { t->ClearCondition(); return; }
    auto items = [&](RexxObjectPtr o) {
        RexxObjectPtr n = temps(t->SendMessage0(o, "ITEMS"));
        wholenumber_t v = 0;
        if (n != NULLOBJECT) t->WholeNumber(n, &v);
        return static_cast<std::size_t>(v);
    };
    const std::size_t now = items(routines) + items(classes);
    if (now == merged) return;
    merged = now;
    static thread_local RexxRoutineObject merge = NULLOBJECT;
    if (merge == NULLOBJECT) {
        const char *source =
            "use arg rx2cppLibrary, rx2cppRoutines, rx2cppClasses\n"
            "rx2cppMerged = .package~new('rx2cpp_external_call', .array~new)\n"
            "do rx2cppName over rx2cppRoutines~allIndexes; rx2cppMerged~addPublicRoutine(rx2cppName, rx2cppRoutines[rx2cppName]); end\n"
            "do rx2cppName over rx2cppClasses~allIndexes; rx2cppMerged~addPublicClass(rx2cppName, rx2cppClasses[rx2cppName]); end\n"
            "rx2cppLibrary~addPackage(rx2cppMerged)\n";
        merge = rxobj::internalRoutine(t, t->NewRoutine("rx2cpp_merge", source, std::strlen(source)));
        if (merge == NULLOBJECT) return;
        rxobj::pinRef(t, (RexxObjectPtr)merge);
    }
    RexxArrayObject args = (RexxArrayObject)temps((RexxObjectPtr)t->ArrayOfThree(rxobj::libraryPackage(), routines, classes));
    temps(t->CallRoutine(merge, args));
    if (t->CheckCondition()) t->ClearCondition();
}
// CALL / function call of a routine only the interpreter can resolve (rexxutil SysXxx, external .rex routines), run in a
// small interpreter routine under the caller's NUMERIC settings. An argument that names a stem the callee filled
// (SysFileTree spec, 'files.', ...) is copied back into the caller's compiled variables, as the interpreter would leave it.
// dynamicName: CALL (expression), the routine name computed at run time (passed as one more argument).
inline MessageResult interpreterCall(Variables &vars, const std::string &name, const std::vector<std::optional<Value>> &args,
                                     const std::optional<Value> &dynamicName = std::nullopt) {
    RexxThreadContext *t = rxobj::need();
    rxobj::LocalRefs temps(t);
    rxobj::bifStat("CALL " + name);
    // The stem copy-back below is needed only when an argument may name a stem (a string ending in '.', or an object,
    // whose string value the helper reads); without one the helper is the call alone.
    bool stemArgs = false;
    auto mayNameStem = [](const Value &a) {
        if (a.isObject()) return true;
        if (a.bytes.numCache().meta.load(std::memory_order_acquire) & NumCache::pending) return false;   // a number: no '.' at the end
        const std::string &s = a.bytes.str();
        return !s.empty() && s.back() == '.';
    };
    for (const auto &a : args) if (a && mayNameStem(*a)) stemArgs = true;
    if (dynamicName && mayNameStem(*dynamicName)) stemArgs = true;   // (the routine name is an argument of the helper too)
    // A stem the caller has, named by an argument ('S.'): the callee works on it in place (SysStemSort, SysStemInsert,
    // SysFileTree into an existing stem, ...), as interpreted it would on the caller's own stem. The compiled stem is
    // bound to a stem object shared with the interpreter (stemArg, stemHandle) and passed to the helper, which makes it
    // its own variable of that name (USE ARG); no copy back for it after the call.
    std::vector<std::pair<std::string, void *>> sharedStems;
    if (stemArgs) {
        auto stemName = [](const std::string &s) {   // a plain stem name: a symbol, one period, at the end
            if (s.size() < 2 || s.back() != '.') return std::string();
            std::string u;
            for (std::size_t i = 0; i + 1 < s.size(); ++i) {
                const unsigned char c = static_cast<unsigned char>(s[i]);
                if (!(std::isalnum(c) || c == '_' || c == '!' || c == '?')) return std::string();
                u += static_cast<char>(std::toupper(c));
            }
            if (std::isdigit(static_cast<unsigned char>(u[0]))) return std::string();
            return u + '.';
        };
        for (const auto &a : args) {
            if (!a || a->isObject()) continue;
            const std::string name = stemName(a->bytes.str());
            if (name.empty()) continue;
            bool have = boundStem(vars, name) != nullptr || lookup(vars, name) != nullptr;
            if (!have) {
                const Variables &owner = variableOwner(vars, name);
                for (const auto &e : owner)
                    if (e.first.size() > name.size() && e.first.compare(0, name.size(), name) == 0) { have = true; break; }
            }
            if (!have) continue;
            bool seen = false;
            for (const auto &s : sharedStems) if (s.first == name) seen = true;
            if (seen) continue;
            Value obj = stemArg(vars, name);
            auto *so = dynamic_cast<StemObject *>(obj.object.get());
            if (!so) continue;
            sharedStems.emplace_back(name, EnvObject::stemHandle(*so));
        }
    }
    // One helper per call shape (NUMERIC settings, routine, which arguments are present, stem copy-back): looked up by
    // the shape, its source written only the first time.
    std::string key;
    key.reserve(name.size() + args.size() + 24);
    key += std::to_string(vars.numeric.digits); key += ','; key += std::to_string(vars.numeric.fuzz);
    key += vars.numeric.engineering ? 'E' : 'S'; key += stemArgs ? '.' : '-'; key += dynamicName ? '(' : ' ';
    key += sharedStems.empty() ? ' ' : 'U';
    for (const auto &a : args) key += a ? 'a' : '_';
    key += name;
    struct Helper { RexxRoutineObject routine; std::size_t merged; };
    static thread_local std::unordered_map<std::string, Helper> cache;
    auto it = cache.find(key);
    if (it == cache.end()) {
        std::string call = dynamicName ? "call (arg(" + std::to_string(args.size() + 1) + ")) " : "call " + name + " ";
        for (std::size_t i = 0; i < args.size(); ++i) {
            if (i) call += ",";
            if (args[i]) call += "arg(" + std::to_string(i + 1) + ")";
        }
        // End the clause explicitly: a trailing omitted argument leaves a final comma, which at the end of a line would
        // continue the clause into the next one (f(a,) has 2 arguments, the second omitted).
        call += ";";
        // shared stems: (name, stem) pairs after the arguments, each made the helper's variable of that name
        const std::string shared = sharedStems.empty() ? std::string() :
            "do rx2cppJ = " + std::to_string(args.size() + (dynamicName ? 1 : 0) + 1) +
            " to arg() by 2; interpret 'use arg' copies(',', rx2cppJ) arg(rx2cppJ); end\n";
        std::string source =
            "numeric digits " + std::to_string(vars.numeric.digits) + "; numeric fuzz " + std::to_string(vars.numeric.fuzz) +
            "; numeric form " + (vars.numeric.engineering ? "engineering" : "scientific") + "\n" + shared + call +
            "\nout = .array~new; if var('RESULT') then out[1] = result\n";
        if (stemArgs)
            source += "do i = 1 to " + std::to_string(args.size() + (dynamicName ? 1 : 0)) + "; if \\arg(i, 'E') then iterate; a = arg(i)\n"
                      "  if \\a~isA(.string) then iterate; if right(a, 1) \\== '.' | symbol(a) \\== 'VAR' then iterate\n"
                      "  interpret 'st =' a; if st~isA(.stem) then out~append(.array~of(translate(a), st))\n"
                      "end\n";
        source += "return out\n";
        RexxRoutineObject made = rxobj::packageRoutine(t, "rx2cpp_call", source);
        if (made == NULLOBJECT) throw std::runtime_error("cannot create interpreter call for " + name);
        rxobj::pinRef(t, (RexxObjectPtr)made);
        it = cache.emplace(key, Helper{made, 0}).first;
    }
    RexxRoutineObject routine = it->second.routine;
    const std::size_t base = args.size() + (dynamicName ? 1 : 0);
    RexxArrayObject arr = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(base + 2 * sharedStems.size()));
    for (std::size_t k = 0; k < sharedStems.size(); ++k) {
        t->ArrayPut(arr, temps((RexxObjectPtr)t->NewStringFromAsciiz(sharedStems[k].first.c_str())), base + 2 * k + 1);
        t->ArrayPut(arr, (RexxObjectPtr)sharedStems[k].second, base + 2 * k + 2);
    }
    std::vector<rxobj::Arg> conv;
    for (std::size_t i = 0; i < args.size(); ++i) {
        if (!args[i]) continue;
        conv.clear(); EnvObject::convert({*args[i]}, conv);
        RexxObjectPtr o = conv[0].obj ? (RexxObjectPtr)conv[0].obj : temps((RexxObjectPtr)t->NewString(conv[0].bytes.data(), conv[0].bytes.size()));
        t->ArrayPut(arr, o, i + 1);
    }
    if (dynamicName) {
        conv.clear(); EnvObject::convert({*dynamicName}, conv);
        t->ArrayPut(arr, conv[0].obj ? (RexxObjectPtr)conv[0].obj : temps((RexxObjectPtr)t->NewString(conv[0].bytes.data(), conv[0].bytes.size())), args.size() + 1);
    }
    RexxObjectPtr r = temps(t->CallRoutine(routine, arr));
    if (t->CheckCondition()) {
        RexxCondition cd; t->DecodeConditionInfo(t->GetConditionInfo(), &cd);
        std::string code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        std::string text = (cd.message && t->IsString(cd.message)) ? t->ObjectToStringValue(cd.message) : "error in " + name;
        RexxDirectoryObject info = t->GetConditionInfo();
        rxobj::keepCondition(t);
        t->ClearCondition();
        rxobj::captureAdditional(t, info);   // the message substitutions (43.1 "Could not find routine &1"), no condition pending
        SyntaxCondition raised(code, text, false);
        for (const std::string &a : rxobj::lastAdditional()) raised.substitutions.push_back(Value::string(a));
        raised.conditionObject = takeKeptCondition();
        throw raised;
    }
    mergeExternalCall(t, routine, it->second.merged);
    if (r == NULLOBJECT) return std::nullopt;
    RexxArrayObject out = (RexxArrayObject)r;
    auto text = [&](RexxObjectPtr o) { RexxStringObject so = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(o)); return std::string(t->StringData(so), t->StringLength(so)); };
    auto valueOf = [&](RexxObjectPtr o) -> Value {
        if (o == t->Nil()) return nil();
        if (rxobj::isPlainString(t, o)) return Value::string(text(o));
        return EnvObject::adopt((void *)rxobj::pinRef(t, o));
    };
    const std::size_t n = t->ArraySize(out);
    for (std::size_t i = 2; i <= n; ++i) {
        RexxArrayObject pair = (RexxArrayObject)t->ArrayAt(out, i);
        const std::string stem = text(t->ArrayAt(pair, 1));
        RexxObjectPtr st = t->ArrayAt(pair, 2);
        bool inPlace = false;
        for (const auto &s : sharedStems) if (s.first == stem) inPlace = true;
        if (inPlace) continue;   // (the caller's own stem object: already changed)
        resetStem(vars, stem);
        RexxArrayObject tails = (RexxArrayObject)temps(t->SendMessage0(st, "ALLINDEXES"));
        const std::size_t m = tails ? t->ArraySize(tails) : 0;
        for (std::size_t k = 1; k <= m; ++k) {
            RexxObjectPtr tail = t->ArrayAt(tails, k);
            RexxObjectPtr v = temps(t->SendMessage1(st, "[]", tail));
            set(vars, stem + text(tail), valueOf(v));
        }
    }
    RexxObjectPtr res = t->ArrayAt(out, 1);
    if (res == NULLOBJECT) return std::nullopt;
    return valueOf(res);
}
// ADDRESS environment command: the interpreter that loaded this library runs the command with its own environment
// handlers (same shell, same output, same RC); RC is then set in the compiled method's variables.
// Not yet: ERROR / FAILURE conditions for a SIGNAL ON / CALL ON trap in the compiled method.
inline void interpreterCommand(Variables &vars, const Value &environment, const Value &command) {
    RexxThreadContext *t = rxobj::need();
    rxobj::LocalRefs temps(t);
    rxobj::bifStat("ADDRESS " + environment.bytes.str());
    // ERROR / FAILURE: when the activation traps them, the helper does too (CALL ON: the command completes, RC is set,
    // and its condition comes back), so the interpreter decides which one a command raises (FAILURE untrapped: ERROR).
    const int mode = MethodTraps::commandConditionMode() & 7;
    static thread_local RexxRoutineObject routines[8] = {};
    RexxRoutineObject &routine = routines[mode];
    if (routine == NULLOBJECT) {
        // (the activation's TRACE setting: TRACE OFF keeps a failing command quiet, as interpreted)
        std::string source = "use arg rx2cppEnvironment, rx2cppCommand, rx2cppTrace, rx2cppContext\ntrace value rx2cppTrace\nrx2cppQueue = .array~new\n";
        if (mode & 1) source += "call on error name rx2cppQueued\n";
        if (mode & 2) source += "call on failure name rx2cppQueued\n";
        if (mode & 4) source += "call on any name rx2cppQueued\n";
        // (.RS through the caller-context routine: the helper's own, with no environment symbol to look up)
        source += "address value rx2cppEnvironment\nrx2cppCommand\n"
                  "if rx2cppContext == .nil then return .array~of(rc, rx2cppQueue, .context~rs)\n"
                  "return .array~of(rc, rx2cppQueue, rx2cppContext~call~rs)\n"
                  "rx2cppQueued: if rx2cppQueue~append(condition('O')) > 0 then nop\nreturn\n";
        routine = rxobj::helperRoutine(t, t->NewRoutine("rx2cpp_address", source.c_str(), source.size()));
        if (routine == NULLOBJECT) throw std::runtime_error("cannot create interpreter ADDRESS helper");
        rxobj::pinRef(t, (RexxObjectPtr)routine);
    }
    std::vector<rxobj::Arg> conv;
    RexxArrayObject arr = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(4));
    {
        RexxObjectPtr context = rxobj::callerContextRoutine(t);
        t->ArrayPut(arr, context != NULLOBJECT ? context : t->Nil(), 4);
    }
    std::size_t index = 0;
    const Value trace = Value::string(traceSetting());
    for (const Value *v : {&environment, &command, &trace}) {
        conv.clear(); EnvObject::convert({*v}, conv);
        RexxObjectPtr o = conv[0].obj ? (RexxObjectPtr)conv[0].obj : temps((RexxObjectPtr)t->NewString(conv[0].bytes.data(), conv[0].bytes.size()));
        t->ArrayPut(arr, o, ++index);
    }
    RexxObjectPtr r = temps(t->CallRoutine(routine, arr));
    if (t->CheckCondition()) {
        RexxCondition cd; t->DecodeConditionInfo(t->GetConditionInfo(), &cd);
        std::string code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        std::string text = (cd.message && t->IsString(cd.message)) ? t->ObjectToStringValue(cd.message) : "error in ADDRESS";
        RexxDirectoryObject info = t->GetConditionInfo();
        rxobj::keepCondition(t);
        t->ClearCondition();
        rxobj::captureAdditional(t, info);   // the message substitutions (43.1 "Could not find routine &1"), no condition pending
        SyntaxCondition raised(code, text, false);
        for (const std::string &a : rxobj::lastAdditional()) raised.substitutions.push_back(Value::string(a));
        raised.conditionObject = takeKeptCondition();
        throw raised;
    }
    if (r == NULLOBJECT || !t->IsArray(r)) throw std::runtime_error("ADDRESS helper returned no RC");
    RexxObjectPtr rc = t->ArrayAt((RexxArrayObject)r, 1);
    if (rc == NULLOBJECT) throw std::runtime_error("ADDRESS helper returned no RC");
    RexxStringObject rs = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(rc));
    set(vars, "RC", Value::string(std::string(t->StringData(rs), t->StringLength(rs))));
    // .RS of this activation: the command's return status, as the helper saw it
    if (RexxObjectPtr status = t->ArrayAt((RexxArrayObject)r, 3)) if (ActivationScope *a = ActivationScope::current()) {
        std::int64_t n = 0;
        if (t->ObjectToInt64(status, &n)) a->returnStatus = static_cast<int>(n);
    }
    // the command's condition, raised in this activation (SIGNAL ON: now; CALL ON: at the clause boundary)
    RexxObjectPtr queued = t->ArrayAt((RexxArrayObject)r, 2);
    if (queued != NULLOBJECT && t->IsArray(queued)) {
        const std::size_t n = t->ArrayItems((RexxArrayObject)queued);
        for (std::size_t i = 1; i <= n; ++i) {
            RexxObjectPtr cond = t->ArrayAt((RexxArrayObject)queued, i);
            if (cond == NULLOBJECT) continue;
            RexxObjectPtr nameObj = t->DirectoryAt((RexxDirectoryObject)cond, "CONDITION");
            const std::string conditionName = nameObj != NULLOBJECT && t->IsString(nameObj) ? t->ObjectToStringValue(nameObj) : std::string("ERROR");
            auto object = std::make_shared<EnvObject>((void *)rxobj::pinRef(t, cond));
            const int use = [&] { ActivationScope *a = ActivationScope::current(); return a && a->traps ? a->traps->trapping(conditionName, a->traps->find(conditionName)) : -1; }();
            if (use >= 0 && !ActivationScope::current()->traps->callMode[use])
                object->sendMessage("PUT", {Value::string("SIGNAL"), Value::string("INSTRUCTION")});
            MethodTraps::deliver(conditionName, object);
        }
    }
}
// SAY in a native library: the line goes to the interpreter's .OUTPUT (~SAY), as interpreted SAY output does, so a
// redirected .OUTPUT (a Monitor on a stream, ...) receives it and the order with interpreted output is kept.
inline void hostSay(const std::string &line) {
    RexxThreadContext *t = rxobj::need();
    rxobj::LocalRefs temps(t);
    RexxDirectoryObject local = (RexxDirectoryObject)temps((RexxObjectPtr)t->GetLocalEnvironment());
    RexxObjectPtr stream = local ? t->DirectoryAt(local, "OUTPUT") : NULLOBJECT;
    if (stream == NULLOBJECT || stream == t->Nil()) { std::fwrite(line.data(), 1, line.size(), stdout); std::fputc('\n', stdout); return; }
    temps(t->SendMessage1(stream, "SAY", temps((RexxObjectPtr)t->NewString(line.data(), line.size()))));
    if (t->CheckCondition()) {
        RexxCondition cd; t->DecodeConditionInfo(t->GetConditionInfo(), &cd);
        std::string code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        std::string text = (cd.message && t->IsString(cd.message)) ? t->ObjectToStringValue(cd.message) : std::string("error in SAY");
        RexxDirectoryObject info = t->GetConditionInfo();
        rxobj::keepCondition(t);
        t->ClearCondition();
        rxobj::captureAdditional(t, info);
        SyntaxCondition raised(code, text, false);
        for (const std::string &a : rxobj::lastAdditional()) raised.substitutions.push_back(Value::string(a));
        raised.conditionObject = takeKeptCondition();
        throw raised;
    }
}
inline const bool hostSayInstalled = (sayHook() = &hostSay, true);
inline void promoteStem(StemObject &st) { (void)EnvObject::stemHandle(st); }
inline const bool stemPromoteInstalled = (StemObject::promoteHook() = &promoteStem, true);
inline bool foreignStem(const Value &v) {
    auto *e = v.isObject() ? dynamic_cast<EnvObject *>(v.object.get()) : nullptr;
    return e && rxobj::need()->IsStem((RexxObjectPtr)e->handle);
}
inline const bool foreignStemInstalled = (StemObject::foreignStemHook() = &foreignStem, true);
// Runs one small interpreter helper (source, arguments); a condition it raises is re-raised in the compiled code as is.
inline RexxObjectPtr interpreterHelper(RexxThreadContext *t, rxobj::LocalRefs &temps, RexxRoutineObject &routine,
                                       const char *name, const char *source, const std::vector<Value> &args) {
    if (routine == NULLOBJECT) {
        // (the collection helper is the compiled code's machinery, not its code: no security manager is asked for it)
        RexxRoutineObject made = t->NewRoutine(name, source, std::strlen(source));
        routine = std::strcmp(name, "rx2cpp_gc") == 0 ? rxobj::internalRoutine(t, made) : rxobj::helperRoutine(t, made);
        if (routine == NULLOBJECT) throw std::runtime_error(std::string("cannot create interpreter helper ") + name);
        rxobj::pinRef(t, (RexxObjectPtr)routine);
    }
    std::vector<rxobj::Arg> conv;
    RexxArrayObject arr = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(args.size()));
    std::size_t index = 0;
    for (const Value &v : args) {
        conv.clear(); EnvObject::convert({v}, conv);
        RexxObjectPtr o = conv[0].obj ? (RexxObjectPtr)conv[0].obj : temps((RexxObjectPtr)t->NewString(conv[0].bytes.data(), conv[0].bytes.size()));
        t->ArrayPut(arr, o, ++index);
    }
    RexxObjectPtr r = temps(t->CallRoutine(routine, arr));
    if (t->CheckCondition()) {
        RexxCondition cd; t->DecodeConditionInfo(t->GetConditionInfo(), &cd);
        std::string code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        std::string text = (cd.message && t->IsString(cd.message)) ? t->ObjectToStringValue(cd.message) : std::string("error in ") + name;
        RexxDirectoryObject info = t->GetConditionInfo();
        rxobj::keepCondition(t);
        t->ClearCondition();
        rxobj::captureAdditional(t, info);
        SyntaxCondition raised(code, text, false);
        for (const std::string &a : rxobj::lastAdditional()) raised.substitutions.push_back(Value::string(a));
        raised.conditionObject = takeKeptCondition();
        throw raised;
    }
    return r;
}
// PARSE PULL / PULL (linein false): the interpreter's current external data queue, standard input when it is empty;
// PARSE LINEIN (linein true): standard input. As interpreted, read by the interpreter.
inline Value interpreterParseSource(bool linein) {
    RexxThreadContext *t = rxobj::need();
    rxobj::LocalRefs temps(t);
    static thread_local RexxRoutineObject pull = NULLOBJECT, line = NULLOBJECT;
    RexxObjectPtr r = linein ? interpreterHelper(t, temps, line, "rx2cpp_linein", "parse linein rx2cppLine\nreturn rx2cppLine\n", {})
                             : interpreterHelper(t, temps, pull, "rx2cpp_pull", "parse pull rx2cppLine\nreturn rx2cppLine\n", {});
    if (r == NULLOBJECT) return Value::string(std::string());
    RexxStringObject rs = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(r));
    return Value::string(std::string(t->StringData(rs), t->StringLength(rs)));
}
// PUSH (lifo) / QUEUE: one line onto the interpreter's current external data queue.
inline void interpreterQueue(bool lifo, const Value &line) {
    RexxThreadContext *t = rxobj::need();
    rxobj::LocalRefs temps(t);
    static thread_local RexxRoutineObject push = NULLOBJECT, queue = NULLOBJECT;
    if (lifo) interpreterHelper(t, temps, push, "rx2cpp_push", "push arg(1)\nreturn\n", {line});
    else interpreterHelper(t, temps, queue, "rx2cpp_queue", "queue arg(1)\nreturn\n", {line});
}
// A message sent by a small interpreter routine (mode bits: 1 SIGNAL ON NOTREADY, 2 NOSTRING, 4 LOSTDIGITS, 8 CALL ON
// NOTREADY). A condition the interpreter raises inside it lands in that Rexx activation, as interpreted it lands in the
// method's own activation; trapped there, it goes to the running compiled activation's trap (NotReadyCondition), or -
// CALL ON - the send completes and the condition is queued for the compiled activation's clause boundary.
inline std::optional<Value> trappedSend(const Value &target, const std::string &selector, const std::vector<Value> &args, int mode) {
    RexxThreadContext *t = rxobj::need();
    rxobj::LocalRefs temps(t);
    static thread_local RexxRoutineObject helpers[16] = {};
    RexxArrayObject list = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(args.size()));
    std::vector<rxobj::Arg> conv;
    for (std::size_t i = 0; i < args.size(); ++i) {
        const Value &v = args[i];
        if (v.isObject()) if (auto *e = dynamic_cast<EnvObject *>(v.object.get())) if (e->handle == nullptr) continue;   // omitted
        conv.clear(); EnvObject::convert({v}, conv);
        t->ArrayPut(list, conv[0].obj ? (RexxObjectPtr)conv[0].obj : temps((RexxObjectPtr)t->NewString(conv[0].bytes.data(), conv[0].bytes.size())), i + 1);
    }
    const std::vector<Value> helperArgs{target, Value::string(selector), EnvObject::adopt((void *)rxobj::pinRef(t, (RexxObjectPtr)list))};
    static const char body[] = "rx2cppMsg = .message~new(rx2cppTarget, rx2cppMessage, 'A', rx2cppArgs)\nrx2cppMsg~send\n"
                               "if rx2cppMsg~hasResult then return .array~of(rx2cppMsg~result)\nreturn .array~new(0)\n"
                               "rx2cppCondition: return .array~of(.nil, condition('O'))\n";
    static const char queuedBody[] = "rx2cppMsg = .message~new(rx2cppTarget, rx2cppMessage, 'A', rx2cppArgs)\nrx2cppMsg~send\n"
                                     "rx2cppOut = .array~new(3); rx2cppOut[3] = rx2cppQueue\n"
                                     "if rx2cppMsg~hasResult then rx2cppOut[1] = rx2cppMsg~result\nreturn rx2cppOut\n"
                                     "rx2cppCondition: return .array~of(.nil, condition('O'))\n"
                                     "rx2cppQueued: if rx2cppQueue~append(condition('O')) > 0 then nop\nreturn\n";
    mode &= 15;
    std::string source = "use arg rx2cppTarget, rx2cppMessage, rx2cppArgs\n";
    if (mode & 8) source += "rx2cppQueue = .array~new\ncall on notready name rx2cppQueued\n";
    else if (mode & 1) source += "signal on notready name rx2cppCondition\n";
    if (mode & 2) source += "signal on nostring name rx2cppCondition\n";
    if (mode & 4) source += "signal on lostdigits name rx2cppCondition\n";
    source += (mode & 8) ? queuedBody : body;
    const std::string helperName = "rx2cpp_send_" + std::to_string(mode);
    RexxObjectPtr r = interpreterHelper(t, temps, helpers[mode], helperName.c_str(), source.c_str(), helperArgs);
    if (r == NULLOBJECT) return std::nullopt;
    RexxArrayObject out = (RexxArrayObject)r;
    if (t->ArraySize(out) >= 2) {
        RexxObjectPtr cond = t->ArrayAt(out, 2);
        if (cond != NULLOBJECT && cond != t->Nil()) {
            RexxObjectPtr name = t->DirectoryAt((RexxDirectoryObject)cond, "CONDITION");
            std::string conditionName = name != NULLOBJECT && t->IsString(name) ? t->ObjectToStringValue(name) : std::string("NOTREADY");
            throw NotReadyCondition(std::make_shared<EnvObject>((void *)rxobj::pinRef(t, cond)), conditionName);
        }
    }
    if (t->ArraySize(out) >= 3) if (RexxObjectPtr queued = t->ArrayAt(out, 3)) if (t->IsArray(queued)) {
        const std::size_t n = t->ArrayItems((RexxArrayObject)queued);
        for (std::size_t i = 1; i <= n; ++i)
            if (RexxObjectPtr cond = t->ArrayAt((RexxArrayObject)queued, i))
                MethodTraps::deliver("NOTREADY", std::make_shared<EnvObject>((void *)rxobj::pinRef(t, cond)));
    }
    if (t->ArraySize(out) == 0) return std::nullopt;
    RexxObjectPtr res = t->ArrayAt(out, 1);
    if (res == NULLOBJECT) return std::nullopt;
    if (rxobj::isPlainString(t, res)) {
        RexxStringObject so = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(res));
        return Value::string(std::string(t->StringData(so), t->StringLength(so)));
    }
    return EnvObject::adopt((void *)rxobj::pinRef(t, res));
}
// One stream method of a stream BIF: through trappedSend always (NOTREADY must not reach an interpreted caller).
inline Value streamSend(const Value &stream, const std::string &selector, const std::vector<Value> &args) {
    auto r = trappedSend(stream, selector, args, MethodTraps::interpreterConditionMode());
    return r ? *r : Value::string(std::string());
}
// Message sends of compiled code to interpreter objects while the activation traps interpreter-raised conditions.
inline std::optional<std::optional<Value>> trappedEnvSend(void *handle, const std::string &selector, const std::vector<Value> &args) {
    const int mode = MethodTraps::interpreterConditionMode();
    if (mode == 0) return std::nullopt;
    RexxThreadContext *t = rxobj::need();
    const Value target = EnvObject::adopt((void *)rxobj::pinRef(t, (RexxObjectPtr)handle));
    return std::optional<std::optional<Value>>(trappedSend(target, selector, args, mode));
}
inline const bool trappedSendInstalled = (trappedSendHook() = &trappedEnvSend, true);
// Memory pressure from compiled strings (rx::notePressure): the interpreter collects, as GC('F') does. Interpreted, the
// same churn would also have pushed the objects made just before it out of the interpreter's save stack (a push-through
// stack of the last 10 new objects, which the collector treats as live); a few throwaway objects do that first.
inline void interpreterCollect() {
    static const bool trace = std::getenv("RX2CPP_GC_TRACE") != nullptr;
    if (trace) std::fprintf(stderr, "rx2cpp: collect requested (%s)\n", rxobj::current ? "running" : "no context");
    if (!rxobj::current) return;
    RexxThreadContext *t = rxobj::current;
    rxobj::LocalRefs temps(t);
    static thread_local RexxRoutineObject gc = NULLOBJECT;
    (void)interpreterHelper(t, temps, gc, "rx2cpp_gc", "do 12; rx2cppJunk = .object~new; end\ncall gc 'F'\n", {});
}
inline const bool collectInstalled = (collectHook() = &interpreterCollect, true);
// INTERPRET in a compiled method or routine. The interpreter runs the string as a method of SELF (a routine where there is
// no SELF) created in the library's package, with this activation's arguments, its NUMERIC settings and a copy of every
// variable it can see (stems are shared: they become interpreter stems both sides use). Afterwards the variables come
// back (new, changed and DROPped ones) with the NUMERIC settings. A RETURN or EXIT in the string ends this activation:
// the answer is then the value to return (no value: rx::noResult()), otherwise nullopt.
inline std::atomic<unsigned long> &interpretCounter() { static std::atomic<unsigned long> n{0}; return n; }
// INTERPRET data must not contain labels (47.1, a translation error: nothing of the string runs). A label is a symbol
// followed by ':' where a clause starts (after ';', a line end that is not a continuation, or another label).
inline void interpretLabelCheck(const std::string &src) {
    auto symbolChar = [](char c) { return std::isalnum(static_cast<unsigned char>(c)) || c == '.' || c == '_' || c == '!' || c == '?'; };
    bool clauseStart = true, continued = false;
    std::size_t i = 0, n = src.size();
    while (i < n) {
        const char c = src[i];
        if (c == ' ' || c == '\t' || c == '\r') { ++i; continue; }
        if (c == '\n') { if (!continued) clauseStart = true; continued = false; ++i; continue; }
        if (c == '/' && i + 1 < n && src[i + 1] == '*') {          // nested comments
            int depth = 0;
            while (i < n) {
                if (src[i] == '/' && i + 1 < n && src[i + 1] == '*') { ++depth; i += 2; }
                else if (src[i] == '*' && i + 1 < n && src[i + 1] == '/') { i += 2; if (--depth == 0) break; }
                else ++i;
            }
            continue;
        }
        if (c == '-' && i + 1 < n && src[i + 1] == '-') { while (i < n && src[i] != '\n') ++i; continue; }
        continued = false;
        if (c == ';') { clauseStart = true; ++i; continue; }
        if (c == '\'' || c == '"') {
            ++i;
            while (i < n) { if (src[i] == c) { if (i + 1 < n && src[i + 1] == c) { i += 2; continue; } ++i; break; } ++i; }
            clauseStart = false;
            continue;
        }
        if (symbolChar(c)) {
            const std::size_t first = i;
            while (i < n && symbolChar(src[i])) ++i;
            if (clauseStart) {
                std::size_t k = i;
                while (k < n && (src[k] == ' ' || src[k] == '\t')) ++k;
                if (k < n && src[k] == ':' && !(k + 1 < n && src[k + 1] == ':')) {
                    std::string label = src.substr(first, i - first);
                    for (char &ch : label) ch = static_cast<char>(std::toupper(static_cast<unsigned char>(ch)));
                    SyntaxCondition e("47.1", "INTERPRET data must not contain labels; found \"" + label + "\"", false);
                    e.substitutions.push_back(Value::string(label));
                    throw e;
                }
            }
            clauseStart = false;
            continue;
        }
        if (c == ',') {   // a comma that ends the line continues the clause
            std::size_t k = i + 1;
            while (k < n && (src[k] == ' ' || src[k] == '\t' || src[k] == '\r')) ++k;
            continued = k >= n || src[k] == '\n';
        }
        clauseStart = false;
        ++i;
    }
}
inline std::optional<Value> interpretInActivation(Variables &vars, const Value &code,
                                                 const std::vector<std::optional<Value>> &arguments) {
    if (code.isObject()) throw std::runtime_error("INTERPRET of an object is not implemented");
    interpretLabelCheck(code.bytes);
    RexxThreadContext *t = rxobj::need();
    rxobj::LocalRefs temps(t);
    // the visible variables: this pool's, then exposed ones (a stem by its stem object)
    std::vector<std::string> names;
    std::unordered_set<std::string> stems;
    forEachVariable(vars, [&](const std::string &name, const Value &) {
        const std::size_t dot = name.find('.');
        if (dot == std::string::npos) names.push_back(name);
        else stems.insert(name.substr(0, dot + 1));
    });
    vars.exposed.any([&](const char *e, std::size_t len) {
        const std::string n(e, len);
        if (!n.empty() && n.back() == '.') stems.insert(n);
        else if (lookup(vars, n)) names.push_back(n);
        return false;
    });
    for (const std::string &st : stems) { (void)stemArg(vars, st); names.push_back(st); }
    RexxDirectoryObject in = (RexxDirectoryObject)temps((RexxObjectPtr)t->NewDirectory());
    std::vector<rxobj::Arg> conv;
    for (const std::string &n : names) {
        const Value *v = lookup(vars, n);
        if (!v) continue;
        conv.clear(); EnvObject::convert({*v}, conv);
        RexxObjectPtr o = conv[0].obj ? (RexxObjectPtr)conv[0].obj : temps((RexxObjectPtr)t->NewString(conv[0].bytes.data(), conv[0].bytes.size()));
        t->DirectoryPut(in, o, n.c_str());
    }
    const std::string key = "RX2CPP.INTERPRET." + std::to_string(++interpretCounter());
    RexxDirectoryObject local = (RexxDirectoryObject)temps((RexxObjectPtr)t->GetLocalEnvironment());
    t->DirectoryPut(local, (RexxObjectPtr)in, key.c_str());
    const ActivationNumeric &num = vars.numeric;
    // (the code's scaffolding names no environment symbol, which a security manager would be asked about: RX2CPP_TAKE and
    // RX2CPP_CALLER_CONTEXT are routines of the declaration package, the code's package's parent)
    std::string source = "rx2cppIn = RX2CPP_TAKE('" + key + "')\n"
        "do rx2cppName over rx2cppIn~allIndexes; call value rx2cppName, rx2cppIn~at(rx2cppName); end\n"
        "drop rx2cppIn rx2cppName\n"
        "numeric digits " + std::to_string(num.digits) + "; numeric fuzz " + std::to_string(num.fuzz) +
        "; numeric form " + (num.engineering ? "engineering" : "scientific") + "\n";
    // the activation's condition traps apply to the string too: a trapped condition comes back to this activation
    // (a CALL ON trap: the string's handler queues the condition, for this activation's clause boundary)
    const std::vector<std::pair<std::string, bool>> armed = MethodTraps::armedConditions();
    bool signalArmed = false, callArmed = false;
    for (const auto &c : armed) {
        if (c.second) { source += "call on " + c.first + " name rx2cppQueued\n"; callArmed = true; }
        else { source += "signal on " + c.first + " name rx2cppTrapped\n"; signalArmed = true; }
    }
    const std::string queueKey = key + ".Q";
    if (callArmed) t->DirectoryPut(local, temps((RexxObjectPtr)t->NewArray(0)), queueKey.c_str());
    source += code.bytes.str();
    source += "\nreturn .array~of('" + key + "', RX2CPP_CALLER_CONTEXT()~variables, digits(), fuzz(), form())\n";
    if (signalArmed)
        source += "rx2cppTrapped: return .array~of('" + key + "', RX2CPP_CALLER_CONTEXT()~variables, digits(), fuzz(), form(), condition('O'))\n";
    if (callArmed) source += "rx2cppQueued: if RX2CPP_TAKE('" + queueKey + "', 'K')~append(condition('O')) > 0 then nop\nreturn\n";
    // hand the queued conditions to this activation (MethodTraps::deliver)
    auto deliverQueued = [&] {
        if (!callArmed) return;
        RexxObjectPtr q = temps(t->SendMessage1((RexxObjectPtr)local, "REMOVE", temps((RexxObjectPtr)t->String(queueKey.c_str()))));
        if (t->CheckCondition()) { t->ClearCondition(); return; }
        if (q == NULLOBJECT || !t->IsArray(q)) return;
        const std::size_t n = t->ArrayItems((RexxArrayObject)q);
        for (std::size_t i = 1; i <= n; ++i) {
            RexxObjectPtr cond = t->ArrayAt((RexxArrayObject)q, i);
            if (cond == NULLOBJECT) continue;
            RexxObjectPtr nameObj = t->DirectoryAt((RexxDirectoryObject)cond, "CONDITION");
            const std::string conditionName = nameObj != NULLOBJECT && t->IsString(nameObj) ? t->ObjectToStringValue(nameObj) : std::string("NOTREADY");
            MethodTraps::deliver(conditionName, std::make_shared<EnvObject>((void *)rxobj::pinRef(t, cond)));
        }
    };
    // SELF when there is one: run as its method (the declaration gives every compiled class RX2CPP_INTERPRET)
    Value self = nil();
    if (rxobj::currentSelf != NULLOBJECT) self = selfObject();
    std::vector<Value> args;
    for (const auto &a : arguments) args.push_back(a ? *a : omittedArgument());
    RexxArrayObject argArray = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(args.size()));
    for (std::size_t i = 0; i < args.size(); ++i) {
        if (args[i].isObject()) if (auto *e = dynamic_cast<EnvObject *>(args[i].object.get())) if (!e->handle) continue;
        conv.clear(); EnvObject::convert({args[i]}, conv);
        t->ArrayPut(argArray, conv[0].obj ? (RexxObjectPtr)conv[0].obj : temps((RexxObjectPtr)t->NewString(conv[0].bytes.data(), conv[0].bytes.size())), i + 1);
    }
    // The code is a method (SELF) or routine of a package whose parent is the declaration package, made here so that its
    // package is given the activation's security manager (an INTERPRET runs under its activation's: giveLibrarySecurity).
    static thread_local RexxRoutineObject helper = NULLOBJECT;
    static const char body[] =
        "use arg rx2cppSelf, rx2cppCode, rx2cppArgs\n"
        "if rx2cppSelf \\== .nil then rx2cppMsg = .Message~new(rx2cppSelf, 'RX2CPP_INTERPRET', 'I', rx2cppCode, rx2cppArgs)\n"
        "else rx2cppMsg = .Message~new(rx2cppCode, 'CALLWITH', 'I', rx2cppArgs)\n"
        "rx2cppMsg~send\n"
        "if rx2cppMsg~hasResult then return .array~of(1, rx2cppMsg~result)\n"
        "return .array~of(0)\n";
    Value codeObject = nil();
    {
        const bool asMethod = !self.isObject() || !self.object->isNilObject();
        RexxObjectPtr codeClass = temps((RexxObjectPtr)t->FindClass(asMethod ? "METHOD" : "ROUTINE"));
        RexxArrayObject lines = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(0));
        const std::string text = source;
        std::size_t from = 0;
        while (from <= text.size()) {
            std::size_t nl = text.find('\n', from);
            if (nl == std::string::npos) nl = text.size();
            t->ArrayAppend(lines, temps((RexxObjectPtr)t->NewString(text.data() + from, nl - from)));
            from = nl + 1;
        }
        RexxObjectPtr name = temps((RexxObjectPtr)t->String("INTERPRET"));
        RexxArrayObject made = rxobj::libraryPackage() != NULLOBJECT
            ? (RexxArrayObject)temps((RexxObjectPtr)t->ArrayOfThree(name, (RexxObjectPtr)lines, rxobj::libraryPackage()))
            : (RexxArrayObject)temps((RexxObjectPtr)t->ArrayOfTwo(name, (RexxObjectPtr)lines));
        RexxObjectPtr code = t->SendMessage(codeClass, "NEW", made);
        if (t->CheckCondition()) raisePending(t, "NEW");
        if (asMethod) {
            t->SendMessage0(code, "SETUNGUARDED");
            if (t->CheckCondition()) raisePending(t, "SETUNGUARDED");
            rxobj::giveLibrarySecurity(t, (void *)t->GetMethodPackage((RexxMethodObject)code));
        }
        else rxobj::giveLibrarySecurity(t, (void *)t->GetRoutinePackage((RexxRoutineObject)code));
        codeObject = EnvObject::adopt((void *)rxobj::pinRef(t, code));
        t->ReleaseLocalReference(code);
    }
    std::optional<Value> outcome;
    try {
        RexxObjectPtr r = interpreterHelper(t, temps, helper, "rx2cpp_interpret", body,
            {self, codeObject, EnvObject::adopt((void *)rxobj::pinRef(t, (RexxObjectPtr)argArray))});
        RexxArrayObject out = (RexxArrayObject)r;
        if (t->ArraySize(out) < 2) { deliverQueued(); return Value(noResult()); }           // RETURN / EXIT without a value
        outcome = EnvObject::wrap([&] {
            rxobj::Result res; RexxObjectPtr item = t->ArrayAt(out, 2);
            if (rxobj::isPlainString(t, item)) { res.kind = 1; RexxStringObject str = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(item)); res.bytes.assign(t->StringData(str), t->StringLength(str)); }
            else { res.kind = 2; res.obj = (void *)rxobj::pinRef(t, item); }
            return res;
        }());
    } catch (...) {
        t->SendMessage1((RexxObjectPtr)local, "REMOVE", (RexxObjectPtr)t->String(key.c_str()));
        if (callArmed) t->SendMessage1((RexxObjectPtr)local, "REMOVE", (RexxObjectPtr)t->String(queueKey.c_str()));
        if (t->CheckCondition()) t->ClearCondition();
        throw;
    }
    // normal completion: the epilogue's array, marked with this call's key
    auto *arr = outcome->isObject() ? dynamic_cast<EnvObject *>(outcome->object.get()) : nullptr;
    if (!arr || !t->IsArray((RexxObjectPtr)arr->handle)) { deliverQueued(); return outcome; }
    RexxArrayObject result = (RexxArrayObject)arr->handle;
    RexxObjectPtr mark = t->ArrayAt(result, 1);
    if (mark == NULLOBJECT || !t->IsString(mark) || key != t->ObjectToStringValue(mark)) { deliverQueued(); return outcome; }
    RexxObjectPtr after = t->ArrayAt(result, 2);
    std::unordered_set<std::string> seen;
    RexxObjectPtr indexes = temps(t->SendMessage0(after, "ALLINDEXES"));
    const std::size_t count = t->ArrayItems((RexxArrayObject)indexes);
    for (std::size_t i = 1; i <= count; ++i) {
        RexxObjectPtr nameObj = t->ArrayAt((RexxArrayObject)indexes, i);
        const std::string name = t->ObjectToStringValue(nameObj);
        RexxObjectPtr item = temps(t->SendMessage1(after, "AT", nameObj));
        // (the bytes, not a C string: a value may hold '00'x)
        Value v = rxobj::isPlainString(t, item) ? [&] { RexxStringObject so = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(item));
                                                        return Value::string(std::string(t->StringData(so), t->StringLength(so))); }()
                                                 : EnvObject::adopt((void *)rxobj::pinRef(t, item));
        seen.insert(name);
        if (!name.empty() && name.back() == '.') assignStem(vars, name, std::move(v));
        else set(vars, name, std::move(v));
    }
    for (const std::string &n : names) if (!seen.count(n)) drop(vars, n);
    vars.numeric.digits = std::stoul(t->ObjectToStringValue(t->ArrayAt(result, 3)));
    vars.numeric.fuzz = std::stoul(t->ObjectToStringValue(t->ArrayAt(result, 4)));
    vars.numeric.engineering = std::string(t->ObjectToStringValue(t->ArrayAt(result, 5))) == "ENGINEERING";
    deliverQueued();
    if (t->ArraySize(result) >= 6) {   // a condition the activation traps: raised here
        RexxObjectPtr cond = t->ArrayAt(result, 6);
        RexxObjectPtr nameObj = t->DirectoryAt((RexxDirectoryObject)cond, "CONDITION");
        const std::string conditionName = nameObj != NULLOBJECT && t->IsString(nameObj) ? t->ObjectToStringValue(nameObj) : std::string("SYNTAX");
        throw NotReadyCondition(std::make_shared<EnvObject>((void *)rxobj::pinRef(t, cond)), conditionName);
    }
    return std::nullopt;
}
// SysFileSystem::canonicalizeName (Unix): ~ is the home directory, a relative name is under the current directory, then
// duplicate and trailing slashes, "." and ".." are removed (whether the file exists or not). The stream table key.
inline std::string qualifyStreamName(const std::string &name) {
    std::string full = name;
    if (!full.empty() && full[0] == '~') {
        const std::size_t slash = full.find('/');
        const std::string user = full.substr(1, slash == std::string::npos ? std::string::npos : slash - 1);
        const char *home = nullptr;
        if (user.empty()) home = std::getenv("HOME");
        else if (struct passwd *pw = getpwnam(user.c_str())) home = pw->pw_dir;
        if (home) full = std::string(home) + (slash == std::string::npos ? std::string() : full.substr(slash));
    }
    if (full.empty() || full[0] != '/') {
        char cwd[4096];
        if (!getcwd(cwd, sizeof cwd)) return name;
        full = std::string(cwd) + "/" + full;
    }
    std::string out = "/";
    std::size_t previousSlash = 0;
    for (std::size_t i = 0; i < full.size(); ++i) {
        const char c = full[i];
        const char next = i + 1 < full.size() ? full[i + 1] : '\0';
        if (c == '/') {
            if (next != '.') previousSlash = out.size() - 1;
            if (out.back() == '/') continue;
            out += c;
        } else if (c == '.' && out.back() == '/') {
            if (next == '\0' || next == '/') continue;
            if (next == '.') {
                const char after = i + 2 < full.size() ? full[i + 2] : '\0';
                if (after == '\0' || after == '/') {
                    ++i;
                    out.resize(previousSlash + 1);
                    while (previousSlash > 0) { if (out[--previousSlash] == '/') break; }
                    continue;
                }
            }
            out += c;
        } else out += c;
    }
    if (out.size() > 1 && out.back() == '/') out.pop_back();
    return out;
}
// The stream built-ins (LINEIN LINEOUT LINES CHARIN CHAROUT CHARS STREAM), as BuiltinFunctions.cpp runs them: the name
// resolves (RexxActivation::resolveStream) to the default .INPUT / .OUTPUT ("" or omitted), STDIN STDOUT STDERR, or the
// stream object of this activation's stream table (made with .Stream~new on first use); the BIF then sends the stream
// method with the arguments given. The QUEUE: name and any call the BIF rejects go to the interpreter's own built-in
// (they do not touch the stream table): its result or exact error.
inline Value streamBif(Variables &vars, const std::string &name, const std::vector<std::optional<Value>> &a) {
    auto delegate = [&]() -> Value {
        auto r = interpreterCall(vars, name, a);
        if (!r) throw std::runtime_error("BIF " + name + ": no result");
        return std::move(*r);
    };
    const std::size_t argc = a.size();
    auto text = [&](std::size_t i) -> std::optional<std::string> {
        if (i >= argc || !a[i]) return std::nullopt;
        return a[i]->bytes.str();
    };
    auto upper = [](std::string v) { for (char &c : v) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c))); return v; };
    for (const auto &slot : a) if (slot && slot->isObject()) return delegate();
    const std::optional<std::string> streamName = text(0);
    if (streamName && upper(*streamName) == "QUEUE:") return delegate();
    // positions and counts must be whole numbers (optional_big_integer); anything else is the interpreter's error
    auto whole = [&](std::size_t i) {
        if (i >= argc || !a[i]) return true;
        RexxDecimal d; const char *err = nullptr;
        if (!tryParseRexxDecimal(*a[i], d, err)) return false;
        if (d.exponent >= 0 || d.coefficient == 0) return true;
        if (-d.exponent > decimalDigits(d.coefficient)) return false;
        return d.coefficient % decimalPow10(-d.exponent) == 0;
    };
    auto &table = ActivationScope::streams();
    std::string fullName;
    auto resolve = [&](bool input, bool add) -> Value {
        fullName = streamName ? *streamName : std::string();
        if (!streamName || streamName->empty()) return envClass(input ? "INPUT" : "OUTPUT");
        const std::string u = upper(*streamName);
        if (u == "STDIN" || u == "STDIN:") return envClass("INPUT");
        if (u == "STDOUT" || u == "STDOUT:") return envClass("OUTPUT");
        if (u == "STDERR" || u == "STDERR:") return envClass("ERROR");
        fullName = qualifyStreamName(*streamName);
        auto it = table.find(fullName);
        if (it != table.end()) return it->second;
        // RexxActivation::resolveStream: a stream not yet open is the security manager's first (STREAM, NAME the
        // qualified name; its STREAM entry, when it gives one, is the stream)
        {
            RexxThreadContext *t = rxobj::need();
            // (the activation's manager: RexxActivation::getEffectiveSecurityManager)
            RexxObjectPtr manager = rxobj::securityManagerObject(t, rxobj::activationSecurity(t));
            if (manager != NULLOBJECT) {
                RexxDirectoryObject args = t->NewDirectory();
                t->DirectoryPut(args, (RexxObjectPtr)t->String(fullName.c_str()), "NAME");
                if (askSecurityManager(t, manager, "STREAM", args)) {
                    // (SecurityManager::checkStreamAccess: the answer is the STREAM entry)
                    RexxObjectPtr given = t->DirectoryAt(args, "STREAM");
                    if (t->CheckCondition()) raisePending(t, "AT");
                    if (given != NULLOBJECT) {
                        Value stream = EnvObject::adopt((void *)rxobj::pinRef(t, given));
                        t->ReleaseLocalReference(given);
                        table.emplace(fullName, stream);
                        return stream;
                    }
                }
            }
        }
        MessageResult made = envClass("STREAM").object->sendMessage("NEW", {Value::string(*streamName)});
        if (!made || !made->isObject()) throw std::runtime_error("cannot create stream " + *streamName);
        if (add) table.emplace(fullName, *made);
        return *made;
    };
    auto send = [&](const Value &stream, const std::string &selector, std::vector<Value> args) -> Value {
        while (!args.empty() && args.back().isObject() && dynamic_cast<EnvObject *>(args.back().object.get()) &&
               static_cast<EnvObject *>(args.back().object.get())->handle == nullptr) args.pop_back();
        return streamSend(stream, selector, args);
    };
    auto arg = [&](std::size_t i) { return i < argc && a[i] ? *a[i] : omittedArgument(); };
    if (rx::eqLit(name, "LINEIN") || rx::eqLit(name, "CHARIN")) {
        if (argc > 3 || !whole(1) || !whole(2)) return delegate();
        Value stream = resolve(true, true);
        if (argc <= 1) return send(stream, name, {});
        if (argc == 2) return send(stream, name, {arg(1)});
        return send(stream, name, {arg(1), arg(2)});
    }
    if (rx::eqLit(name, "LINEOUT") || rx::eqLit(name, "CHAROUT")) {
        if (argc > 3 || !whole(2)) return delegate();
        Value stream = resolve(false, true);
        if (argc == 0) return send(stream, name, {});
        if (argc == 1) {
            Value r = send(stream, name, {});
            if (rx::eqLit(name, "LINEOUT")) table.erase(fullName);   // a close request: removeFileName
            return r;
        }
        if (argc == 2) return send(stream, name, {arg(1)});
        return send(stream, name, {arg(1), arg(2)});
    }
    if (rx::eqLit(name, "LINES")) {
        if (argc > 2) return delegate();
        std::string option = "NORMAL";
        if (auto o = text(1)) { if (o->empty()) return delegate(); option = *o; }
        const char opt = static_cast<char>(std::toupper(static_cast<unsigned char>(option[0])));
        if (opt != 'C' && opt != 'N') return delegate();
        Value stream = resolve(true, true);
        Value r = send(stream, "LINES", {Value::string(option)});
        if (opt == 'N' && !r.isObject()) {
            RexxDecimal d; const char *err = nullptr;
            if (tryParseRexxDecimal(r, d, err)) return Value::string(d.coefficient != 0 ? "1" : "0");
        }
        return r;
    }
    if (rx::eqLit(name, "CHARS")) {
        if (argc > 1) return delegate();
        return send(resolve(true, true), "CHARS", {});
    }
    if (rx::eqLit(name, "STREAM")) {
        if (argc < 1 || argc > 3 || !streamName || streamName->empty()) return delegate();
        char action = 'S';
        if (auto op = text(1)) { if (op->empty()) return delegate(); action = static_cast<char>(std::toupper(static_cast<unsigned char>((*op)[0]))); }
        if (action == 'S' || action == 'D') {
            if (argc > 2) return delegate();
            return send(resolve(true, false), action == 'S' ? "STATE" : "DESCRIPTION", {});
        }
        if (action != 'C' || argc < 3 || !a[2]) return delegate();
        const Value command = *a[2];
        auto hasWord = [&](const char *w) {
            std::istringstream in(upper(command.bytes.str())); std::string t;
            while (in >> t) if (t == w) return true;
            return false;
        };
        if (hasWord("OPEN")) {
            Value stream = resolve(true, true);
            Value r = send(stream, "COMMAND", {command});
            if (r.isObject() || r.bytes.str() != "READY:") table.erase(fullName);
            return r;
        }
        if (hasWord("CLOSE")) {
            Value stream = resolve(true, true);
            Value r = send(stream, "COMMAND", {command});
            table.erase(fullName);
            return r;
        }
        if (hasWord("SEEK") || hasWord("POSITION")) return send(resolve(true, true), "COMMAND", {command});
        return send(resolve(true, false), "COMMAND", {command});
    }
    throw std::runtime_error("not a stream built-in: " + name);
}
// RANDOM([min] [, max] [, seed]) as BUILTIN(RANDOM) and RexxActivation::random run it, on this activation's seed (see
// rx::ActivationScope): the same seeded sequences as interpreted. A call the BIF rejects goes to the interpreter's own
// RANDOM for its exact error (after the seed was set, as there).
inline Value randomBif(Variables &vars, const std::vector<std::optional<Value>> &a) {
    auto delegate = [&]() -> Value {
        auto r = interpreterCall(vars, "RANDOM", a);
        if (!r) throw std::runtime_error("BIF RANDOM: no result");
        return std::move(*r);
    };
    const std::size_t argc = a.size();
    if (argc > 3) return delegate();
    for (const auto &slot : a) if (slot && slot->isObject()) return delegate();
    auto intArg = [&](std::size_t i, std::optional<std::int64_t> &out) -> bool {   // optional_integer
        if (i >= argc || !a[i]) return true;
        RexxDecimal d; const char *err = nullptr;
        std::int64_t v = 0;
        if (!tryParseRexxDecimal(*a[i], d, err) || !oorexxWholeNumber(d, 18, true, v)) return false;
        out = v;
        return true;
    };
    std::optional<std::int64_t> mn, mx, sd;
    if (argc == 2 && !a[0] && !a[1]) { mn = 0; mx = 999; }   // RANDOM(,) is not RANDOM()
    else if (!intArg(0, mn) || !intArg(1, mx)) return delegate();
    if (!intArg(2, sd)) return delegate();
    constexpr std::uint64_t factor = 25214903917ULL, adder = 11ULL;
    std::uint64_t &seed = ActivationScope::randomSeed();
    if (sd) {
        if (*sd < 0) return delegate();
        seed = ~static_cast<std::uint64_t>(*sd);
        for (int i = 0; i < 13; ++i) seed = seed * factor + adder;
    }
    seed = seed * factor + adder;
    std::uint64_t bits = seed;
    std::int64_t minimum = 0, maximum = 999;
    if (mn) {
        if (!mx && !sd) maximum = *mn;
        else if (!mx && sd) minimum = *mn;
        else { minimum = *mn; maximum = *mx; }
    } else if (mx) maximum = *mx;
    if (maximum < minimum || maximum - minimum > 999999999) return delegate();
    if (minimum != maximum) {
        std::uint64_t work = 0;
        for (int i = 0; i < 64; ++i) { work <<= 1; work |= (bits & 1ULL); bits >>= 1; }
        minimum += static_cast<std::int64_t>(work % static_cast<std::uint64_t>(maximum - minimum + 1));
    }
    return Value::number(std::to_string(minimum));
}
// RexxActivation::getTime: the clause's time stamp (SystemInterpreter::getCurrentTime on first use in the clause).
inline ClauseClock &clauseTime() {
    ClauseClock &c = ActivationScope::clock();
    if (!c.valid) {
        if (c.elapsedReset) { c.elapsed = c.utc; c.elapsedReset = false; }   // TIME('R') in an earlier clause
        timeval tv; gettimeofday(&tv, nullptr);
        std::tm local{}; time_t secs = tv.tv_sec; localtime_r(&secs, &local);
        constexpr std::int64_t epochBase = 62135596800LL * 1000000LL;   // 0001-01-01 to 1970-01-01
        c.utc = static_cast<std::int64_t>(tv.tv_sec) * 1000000LL + tv.tv_usec + epochBase;
        c.offset = static_cast<std::int64_t>(local.tm_gmtoff) * 1000000LL;
        c.local = c.utc + c.offset;
        c.valid = true;
    }
    return c;
}
// TIME and DATE (BuiltinFunctions.cpp) on this activation's clock: the elapsed timer here; every other form of the
// current time is formatted by the interpreter's own TIME / DATE from the clause's time stamp (input style 'F'), so
// all the TIME / DATE calls of one clause see the same instant. A conversion (an input time or date) is the
// interpreter's, as are rejected calls.
inline Value timeDateBif(Variables &vars, const std::string &name, const std::vector<std::optional<Value>> &a) {
    auto delegate = [&](const std::vector<std::optional<Value>> &args) -> Value {
        auto r = interpreterCall(vars, name, args);
        if (!r) throw std::runtime_error("BIF " + name + ": no result");
        return std::move(*r);
    };
    for (const auto &slot : a) if (slot && slot->isObject()) return delegate(a);
    if (a.size() > 1) return delegate(a);
    char style = 'N';
    if (!a.empty() && a[0]) {
        if (a[0]->bytes.empty()) return delegate(a);
        style = static_cast<char>(std::toupper(static_cast<unsigned char>(a[0]->bytes[0])));
    }
    ClauseClock &c = clauseTime();
    if (rx::eqLit(name, "TIME") && (style == 'E' || style == 'R')) {
        if (c.elapsed == 0) c.elapsed = c.utc;                               // getElapsed: the first call starts it
        const std::int64_t threshold = c.utc - c.elapsed;
        std::string out = "0";
        if (threshold < 0) c.elapsedReset = true;
        else if (threshold > 0) {
            char work[64];
            std::snprintf(work, sizeof work, "%d.%06d", static_cast<int>(threshold / 1000000LL), static_cast<int>(threshold % 1000000LL));
            out = work;
        }
        if (style == 'R') c.elapsedReset = true;
        return Value::string(out);
    }
    std::vector<std::optional<Value>> args;
    args.push_back(a.empty() ? std::nullopt : a[0]);
    args.push_back(Value::string(std::to_string(c.local)));
    args.push_back(Value::string("F"));
    return delegate(args);
}
inline bool streamBifName(const std::string &name) {
    return rx::eqLit(name, "LINEIN") || rx::eqLit(name, "LINEOUT") || rx::eqLit(name, "LINES") || rx::eqLit(name, "CHARIN") || rx::eqLit(name, "CHAROUT") ||
           rx::eqLit(name, "CHARS") || rx::eqLit(name, "STREAM");
}
#endif
}
#endif

#ifdef RX2CPP_HOST_API
#include "rx_native_nine.hpp"
#endif
