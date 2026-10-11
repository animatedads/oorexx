from pathlib import Path
import re,sys
root=Path(sys.argv[1])
for p in root.glob('*.ii'):
    t=p.read_text(errors='ignore')
    # GNU/header surface
    t=re.sub(r'__attribute__\s*\(\(\s*visibility\s*\(\s*"default"\s*\)\s*\)\)', '', t)
    t=re.sub(r'\bnoexcept\s*\([^)]*\)', '', t)
    t=re.sub(r'\bnoexcept\b', '', t)
    t=re.sub(r'\)\s*\(1\)\s*;', ');', t)
    t=re.sub(r'(?m)^\)\s+(?=(?:extern\b|const\b|int\b|utf8proc_))', '', t)

    # MVS 3.8J geometry: 24-bit effective address, 4-byte pointer container.
    for n,v in {
        'DefaultOld2NewSize':'512','DefaultGlobalReferenceSize':'64','ObjectGrain':'8',
        'LargeAllocationUnit':'1024','VeryLargeObjectGrain':'256','MinimumObjectSize':'24',
        'MaximumObjectSize':'16777208','LiveStackSize':'65536','SaveStackSize':'10',
        'MaxImageSize':'3000000','PageSize':'4096'}.items():
        t=re.sub(r'static\s+const\s+size_t\s+'+n+r'\s*=\s*[^;]+;', 'enum { %s = %s };'%(n,v), t)
    t=t.replace('static const size_t MemorySegmentOverhead = sizeof(MemorySegmentHeader);','enum { MemorySegmentOverhead = 16 };')
    t=t.replace('enum { MaximumObjectSize = 4294967295UL - ObjectGrain };','enum { MaximumObjectSize = 16777208 };')
    t=t.replace('enum { MaxFixedArraySize = (Numerics::MAX_WHOLENUMBER / 10) + 1 };','enum { MaxFixedArraySize = 1048576 };')
    t=re.sub(r'static\s+const\s+size_t\s+MaxFixedArraySize\s*=\s*\(Numerics::MAX_WHOLENUMBER\s*/\s*10\)\s*\+\s*1\s*;', 'enum { MaxFixedArraySize = 1048576 };', t)
    t=re.sub(r'static\s+const\s+uint32_t\s+MaxDispatchWait\s*=\s*50\s*;', 'enum { MaxDispatchWait = 50 };', t)
    t=re.sub(r'static\s+const\s+size_t\s+errorRecoveryStack\s*=\s*1024\s*\*\s*\(32\s*\+\s*\(4\s*\*\s*sizeof\(void \*\)\)\)\s*;', 'enum { errorRecoveryStack = 49152 };', t)
    t=re.sub(r'static\s+const\s+uint64_t\s+timeSliceLength\s*=\s*24\s*;', 'enum { timeSliceLength = 24 };', t)
    t=re.sub(r'static\s+const\s+size_t\s+SIZE_BITS\s*=\s*sizeof\(void \*\)\s*\*\s*8\s*;', 'enum { SIZE_BITS = 32 };', t)
    t=t.replace('static const size_t SIZEBITS = (sizeof(size_t) * BYTE_SIZE);','enum { SIZEBITS = 32 };')
    t=t.replace('static const int ROUND = 1;','enum { ROUND = 1 };').replace('static const int NOROUND = 0;','enum { NOROUND = 0 };')
    t=t.replace('= ListClass::DefaultListSize','= 8').replace('= DefaultListSize','= 8')
    t=re.sub(r'static\s+const\s+uintptr_t\s+INTERNALCLASS\s*=\s*[^;]+;', 'static const uintptr_t INTERNALCLASS;', t)
    t=re.sub(r'static\s+const\s+uint64_t\s+RANDOM_FACTOR\s*=\s*25214903917LL\s*;', 'static const uint64_t RANDOM_FACTOR;', t)
    t=re.sub(r'static\s+const\s+uint64_t\s+RANDOM_ADDER\s*=\s*11LL\s*;', 'static const uint64_t RANDOM_ADDER;', t)

    # Core-internal API names needed to parse static declarations. Public API remains deferred.
    prefix = '''struct RexxInstanceInterface { int reserved; };
struct RexxThreadInterface { int reserved; };
struct MethodContextInterface { int reserved; };
struct CallContextInterface { int reserved; };
struct ExitContextInterface { int reserved; };
struct IORedirectorInterface { int reserved; };
'''
    t=prefix+t
    t=t.replace('RXNOOFEXITS', '16')
    t=re.sub(r'MAKERXSTRING\(([^,]+),\s*([^,]+),\s*([^\)]+)\)\s*;', r'{ \1.strptr = \2; \1.strlength = \3; }', t)
    # global placement-new overload used by restore/dead-object placement forms
    t=t.replace('void *operator new(size_t);', 'void *operator new(size_t);\nvoid *operator new(size_t, void *);', 1)

    # MVS platform facades.
    t=t.replace('class SysActivity {\npublic:\n    SysActivity() {}\n    void create(Activity *) {}\n    void terminate() {}\n};',
                'class SysActivity { public: SysActivity() {} int equals(unsigned long) { return 0; } void create(Activity *) {} void terminate() {} };')
    t=t.replace('class SysSemaphore { public: SysSemaphore() {} };',
                'class SysSemaphore { public: SysSemaphore() {} void create() {} void close() {} void post() {} void reset() {} void wait() {} int wait(unsigned long) { return 1; } };')
    if 'SysThread::getMillisecondTicks' in t and 'class SysThread {' not in t:
        t='class SysThread { public: static unsigned long long getMillisecondTicks(){return 0;} static void yield(){} static void sleep(int){} static int longSleep(unsigned long long){return 0;} };\n'+t
    t=t.replace('class SystemInterpreter {\npublic:\n    static void initialize() {}\n    static void terminate() {}\n};',
                'class SystemInterpreter { public: static void initialize(){} static void terminate(){} static void *allocateResultMemory(size_t); static void releaseResultMemory(void *); };')

    # Expand the preprocessed atomic shim itself.  Do not implement pointer
    # arithmetic here; fetch operations are declarations and are provided by the
    # eventual MVS runtime seam.
    t=re.sub(r'template<class T> class atomic \{\s*T v;\s*public:\s*atomic\(T x=0\):v\(x\)\{\}\s*T operator\+\+\(\)\{return \+\+v;\}\s*T operator\+\+\(int\)\{T x=v;\+\+v;return x;\}\s*operator T\(\) const\{return v;\}\s*T load\(\) const\{return v;\}\s*void store\(T x\)\{v=x;\}\s*\};',
      'enum { memory_order_relaxed = 0 }; template<class T> class atomic { T v; public: atomic(T x=0):v(x){} T operator++(){return ++v;} T operator++(int){T x=v;++v;return x;} operator T() const{return v;} T load() const{return v;} T load(int) const{return v;} void store(T x){v=x;} void store(T x,int){v=x;} T fetch_add(T); T fetch_sub(T); };', t, count=1, flags=re.S)

    # Old atomic interface call-site normalization.
    t=t.replace('.load(memory_order_relaxed)', '.load()')
    t=re.sub(r'\.store\(([^,]+),\s*memory_order_relaxed\)', r'.store(\1)', t)
    t=re.sub(r'\.fetch_add\(([^,]+),\s*memory_order_relaxed\)', r'.fetch_add(\1)', t)
    t=re.sub(r'\.fetch_sub\(([^,]+),\s*memory_order_relaxed\)', r'.fetch_sub(\1)', t)

    # Fixed FlagSet multi-any call sites.
    t=re.sub(r'([A-Za-z_][\w.]*)\.any\(([^,()]+),\s*([^,()]+),\s*([^,()]+)\)', r'(\1.test(\2) || \1.test(\3) || \1.test(\4))', t)
    t=re.sub(r'([A-Za-z_][\w.]*)\.any\(([^,()]+),\s*([^,()]+)\)', r'(\1.test(\2) || \1.test(\3))', t)

    # Modern header-only container seam.
    t=re.sub(r'class\s+ActivityList\s*\{.*?vector<Activity \*>\s+activities;\s*\};',
        'class ActivityList { friend class ActivityManager; friend class InterpreterInstance; public: ActivityList(); ActivityList(const ActivityList &); ActivityList &operator=(const ActivityList &); void append(Activity *); size_t items() const; int isEmpty() const; size_t lastIndex() const; Activity *get(size_t) const; Activity *pull(); void removeItem(Activity *); void clear(); void reset(); protected: vector<Activity *> &contents(); private: vector<Activity *> activities; };', t, count=1, flags=re.S)

    # Namespace idioms unsupported by cfront.
    for ns in ('RedirectionType','OutputOption','HandlerType'):
        t=re.sub(r'namespace\s+'+ns+r'\s*\{', 'class '+ns+' { public:', t)
    t=re.sub(r'class\s+OutputOption\s*\{\s*public:(.*?)\}\s*(?=class\s+CommandIOConfiguration)', r'class OutputOption { public:\1 };\n', t, count=1, flags=re.S)
    t=t.replace('makeEnum32bit = 0xffffffff','makeEnum32bit = 2147483647')
    def global_names(m):
        body=re.sub(r'\bextern\s+RexxString\s*\*','static RexxString *',m.group(1))
        return 'class GlobalNames { public:'+body+' };'
    t=re.sub(r'namespace\s+GlobalNames\s*\{(.*?)\}',global_names,t,count=1,flags=re.S)
    t=t.replace('static RexxString *struct _iobuf;','static RexxString *FILE;')
    t=re.sub(r'static\s+const\s+unsigned\s+int\s+INVALID_CHARACTER\s*=\s*0x100\s*;', 'enum { INVALID_CHARACTER = 0x100 };', t)
    t=t.replace('class KeywordEntry\n{\npublic:\n', 'class KeywordEntry\n{\npublic:\n    KeywordEntry() : name(0), length(0), keywordCode(0) {}\n', 1)

    # cfront inline-expansion limits.
    t=re.sub(r'RexxInternalObject\s*\*pop\(\)\s*\{\s*if\s*\(top\s*==\s*0\)\s*\{\s*return\s+0;\s*\}\s*return\s+stack\[--top\];\s*\}', 'RexxInternalObject *pop() { return top == 0 ? 0 : stack[--top]; }', t, flags=re.S)
    t=re.sub(r'inline\s+Activity\s*\*removeFirst\(\)\s*\{\s*if\s*\(isEmpty\(\)\)\s*\{\s*return\s+0;\s*\}\s*Activity\s*\*activity\s*=\s*WaitingActivityQueue::instance\(\)\.queue\.front\(\);\s*WaitingActivityQueue::instance\(\)\.queue\.pop_front\(\);\s*return\s+activity;\s*\}', 'inline Activity *removeFirst() { Activity *activity = isEmpty() ? 0 : WaitingActivityQueue::instance().queue.front(); return activity == 0 ? 0 : (WaitingActivityQueue::instance().queue.pop_front(), activity); }', t, flags=re.S)
    t=re.sub(r'inline\s+RexxString\s*\*stringArgument\(RexxObject\s*\*object,\s*size_t\s+position\)\s*\{\s*if\s*\(object\s*==\s*0\)\s*\{\s*missingArgument\(position\);\s*return\s+GlobalNames::NULLSTRING;\s*\}\s*return\s+object->requiredString\(position\);\s*\}', 'inline RexxString *stringArgument(RexxObject *object, size_t position) { return object == 0 ? (missingArgument(position), GlobalNames::NULLSTRING) : object->requiredString(position); }', t, flags=re.S)
    t=re.sub(r'inline\s+RexxInternalObject\s*\*allocateObject\(size_t\s+allocationLength\)\s*\{\s*DeadObject\s*\*largeObject;\s*largeObject\s*=\s*deadCache\.findBestFit\(allocationLength\);\s*if\s*\(largeObject\s*!=\s*0\)\s*\{\s*requests\+\+;\s*return\s+splitDeadObject\(largeObject,\s*allocationLength,\s*Memory::LargeAllocationUnit\);\s*\}\s*return\s+0;\s*\}', 'inline RexxInternalObject *allocateObject(size_t allocationLength) { DeadObject *largeObject = deadCache.findBestFit(allocationLength); return largeObject == 0 ? 0 : (requests++, splitDeadObject(largeObject, allocationLength, Memory::LargeAllocationUnit)); }', t, flags=re.S)

    # DeadObjectPool helpers exceed the old inline expander.
    t=re.sub(r'inline\s+DeadObject\s*\*getFirst\(\)\s*\{\s*DeadObject\s*\*newObject\s*=\s*anchor\.next;\s*if\s*\(newObject->isReal\(\)\)\s*\{\s*newObject->remove\(\);\s*logHit\(\);\s*return\s+newObject;\s*\}\s*logMiss\(\);\s*return\s+0;\s*\}',
      'inline DeadObject *getFirst() { DeadObject *newObject = anchor.next; return newObject->isReal() ? (newObject->remove(), logHit(), newObject) : (logMiss(), (DeadObject *)0); }', t, flags=re.S)
    t=re.sub(r'inline\s+DeadObject\s*\*getFirstSingle\(\)\s*\{\s*DeadObject\s*\*newObject\s*=\s*anchor\.next;\s*if\s*\(newObject\s*!=\s*0\)\s*\{\s*logHit\(\);\s*anchor\.next\s*=\s*newObject->next;\s*return\s+newObject;\s*\}\s*logMiss\(\);\s*return\s+0;\s*\}',
      'inline DeadObject *getFirstSingle() { DeadObject *newObject = anchor.next; return newObject != 0 ? (logHit(), anchor.next = newObject->next, newObject) : (logMiss(), (DeadObject *)0); }', t, flags=re.S)
    # S/370 is big-endian; avoid static locals inside inline isBigEndian().
    t=re.sub(r'static\s+inline\s+int\s+isBigEndian\(\)\s*\{.*?\}', 'static inline int isBigEndian() { return 1; }', t, count=1, flags=re.S)

    # return void-expression modern rule.
    for old,new in (
      ('return contents->merge(target);','contents->merge(target); return;'),
      ('return contents->putAll(target);','contents->putAll(target); return;'),
      ('return RexxObject::processUnknown(error, messageName, arguments, count, result);','RexxObject::processUnknown(error, messageName, arguments, count, result); return;'),
      ('return HashCollection::put(value, index);','HashCollection::put(value, index); return;')):
        t=t.replace(old,new)
    t=re.sub(r'inline\s+void\s+([A-Za-z_]\w*)\s*\(([^{};]*)\)\s*\{\s*return\s+([^;{}]+);\s*\}', r'inline void \1(\2) { \3; }', t)

    # Classic C++ for-init scope and inline linkage.
    t=t.replace('for (ItemLink i = freeChain; i < totalSize; i++)\n    {\n        entries[i].next = i + 1;\n    }', 'for (ItemLink j = freeChain; j < totalSize; j++)\n    {\n        entries[j].next = j + 1;\n    }')
    t=t.replace('inline void ArrayClass::clearArrayItem(size_t position)','void ArrayClass::clearArrayItem(size_t position)')

    # Protected<T> conversion ranking.
    t=re.sub(r'\s*inline\s+operator\s+void\s*\*\s*\(\)\s*\{\s*return\s*\(void\s*\*\)protectedObject;\s*\}', '', t)
    t=t.replace('if (startScope == 0)','if (startScope.isNull())')

    # CompoundVariableTable nested iterator calls outer methods declared later.
    t=re.sub(r'class\s+TableIterator\s*\{\s*friend\s+class\s+CompoundVariableTable;.*?CompoundVariableTable\s*\*contents;\s*CompoundTableElement\s*\*current;\s*\};',
      'class TableIterator { friend class CompoundVariableTable; public: TableIterator(); ~TableIterator(); int isAvailable(); RexxObject *value(); CompoundTableElement *variable(); RexxString *name(); RexxString *name(RexxString *); void replace(RexxObject *); void next(); private: TableIterator(CompoundVariableTable *); CompoundVariableTable *contents; CompoundTableElement *current; };', t, count=1, flags=re.S)

    # VariableDictionary nested iterator inline bodies also exceed cfront's
    # expander and old nested-class access rules. Preserve exact layout/signatures.
    t=re.sub(r'class\s+VariableIterator\s*\{\s*friend\s+class\s+VariableDictionary;.*?VariableDictionary\s*\*dictionary;\s*HashContents::TableIterator\s+dictionaryIterator;\s*StemClass\s*\*currentStem;\s*CompoundVariableTable::TableIterator\s+stemIterator;\s*int\s+returnStemValue;\s*\};',
      'class VariableIterator { friend class VariableDictionary; public: VariableIterator(); ~VariableIterator(); int isAvailable(); RexxObject *value(); RexxString *name(); void next(); void terminate(); int isActive(); private: VariableIterator(VariableDictionary *); VariableDictionary *dictionary; HashContents::TableIterator dictionaryIterator; StemClass *currentStem; CompoundVariableTable::TableIterator stemIterator; int returnStemValue; };', t, count=1, flags=re.S)

    # VariableDictionary nested access.
    t=t.replace('    VariableIterator iterator();\n    enum { DefaultObjectDictionarySize = 7 };', '    VariableIterator iterator();\n    StringHashContents *cfrontIteratorContents() { return contents; }\n    enum { DefaultObjectDictionarySize = 7 };')
    t=t.replace('dictionaryIterator = dictionary->contents->iterator();','dictionaryIterator = dictionary->cfrontIteratorContents()->iterator();')

    # Small inline bodies with loops/multiple returns.
    t=re.sub(r'inline\s+ControlledLoop\(\)\s*:\s*control\(0\),\s*initial\(0\),\s*to\(0\),\s*by\(0\),\s*ForLoop\(\)\s*\{\s*for\s*\(size_t\s+i\s*=\s*0;\s*i\s*<\s*3;\s*i\+\+\)\s*\{\s*expressions\[i\]\s*=\s*EXP_NONE;\s*\}\s*\}',
      'inline ControlledLoop(): control(0), initial(0), to(0), by(0), ForLoop() { expressions[0] = EXP_NONE; expressions[1] = EXP_NONE; expressions[2] = EXP_NONE; }', t, flags=re.S)
    t=re.sub(r'inline\s+NumberString\s*\*checkNumber\(wholenumber_t\s+digits\)\s*\{\s*if\s*\(digitsCount\s*>\s*digits\)\s*\{\s*return\s+prepareOperatorNumber\(digits\s*\+\s*1,\s*digits,\s*NOROUND\);\s*\}\s*return\s+this;\s*\}',
      'inline NumberString *checkNumber(wholenumber_t digits) { return digitsCount > digits ? prepareOperatorNumber(digits + 1, digits, NOROUND) : this; }', t, flags=re.S)
    t=re.sub(r'enum\s*\{\s*HIBIT\s*=\s*~SSIZE_MAX\s*\};', 'static const size_t HIBIT;', t)
    t=re.sub(r'enum\s*\{\s*LOWBITS\s*=\s*SSIZE_MAX\s*\};', 'static const size_t LOWBITS;', t)

    # Integer and NumberString old lookup/scoping.
    for name in ('value','numberExponent','adjustedSize','adjustedExponent','displayedExponent'):
        t=re.sub(r'\babs\('+name+r'\)', '('+name+' < 0 ? -'+name+' : '+name+')', t)
    t=t.replace('default:\n                    wholenumber_t module = value % divisor;\n                    return module >= 0 ? new_integer(module) : new_integer(divisor + module);', 'default: {\n                    wholenumber_t module = value % divisor;\n                    return module >= 0 ? new_integer(module) : new_integer(divisor + module);\n                }')
    # Declarations after preprocessing guarantee old parser sees them regardless of include origin.
    if 'strtod(' in t and 'double strtod(' not in t: t='double strtod(const char *, char **);\n'+t
    if 'strdup(' in t and 'char *strdup(' not in t: t='char *strdup(const char *);\n'+t
    if 'free(' in t and 'void free(' not in t: t='void free(void *);\n'+t
    if 'isnan(' in t and 'int isnan(' not in t: t='int isnan(double);\n'+t
    t=t.replace('HUGE_VAL', '(1.0e308)')
    t=re.sub(r'\bUINT64_MAX\b','18446744073709551615ULL',t)
    t=re.sub(r'\bINT64_MAX\b','9223372036854775807LL',t)
    t=re.sub(r'\bINT64_MIN\b','(-9223372036854775807LL - 1LL)',t)

    # RegisteredRoutine's public API callback typedef is deliberately absent
    # from the internal facade; declare only the exact callback shape here.
    if 'class RegisteredRoutine' in t and 'typedef size_t RexxRoutineHandler' not in t:
        t=t.replace('class RegisteredRoutine', 'typedef size_t RexxRoutineHandler(const char *, size_t, const CONSTRXSTRING *, const char *, RXSTRING *);\nclass RegisteredRoutine', 1)

    # NumberStringBuilder::finish is in-class modern code with multiple returns.
    # Turn it into one expression-based return so cfront need not expand control flow.
    finish_rx = r'int\s+finish\(\)\s*\{\s*if\s*\(scannedDigits\s*==\s*0\)\s*\{\s*return\s+0;\s*\}\s*if\s*\(!haveNonZero\)\s*\{\s*number->setZero\(\);\s*return\s+1;\s*\}\s*if\s*\(invalidExponent\)\s*\{\s*return\s+0;\s*\}\s*number->digitsCount\s*=\s*current\s*-\s*number->numberDigits;\s*number->numberExponent\s*=\s*\(exponent\s*\*\s*exponentSign\)\s*-\s*decimals;\s*if\s*\(abs\(number->numberExponent\)\s*>\s*Numerics::MAX_EXPONENT\)\s*\{\s*return\s+0;\s*\}\s*if\s*\(\(number->numberExponent\s*\+\s*number->digitsCount\s*-\s*1\)\s*>\s*Numerics::MAX_EXPONENT\)\s*\{\s*return\s+0;\s*\}\s*return\s+1;\s*\}'
    finish_new = 'int finish() { int ok = scannedDigits != 0 && !invalidExponent; if (scannedDigits != 0 && !haveNonZero) { number->setZero(); } if (ok && haveNonZero) { number->digitsCount = current - number->numberDigits; number->numberExponent = (exponent * exponentSign) - decimals; ok = ((number->numberExponent < 0 ? -number->numberExponent : number->numberExponent) <= Numerics::MAX_EXPONENT) && ((number->numberExponent + number->digitsCount - 1) <= Numerics::MAX_EXPONENT); } return ok; }'
    t=re.sub(finish_rx, finish_new, t, count=1, flags=re.S)

    # Scanner uses repeated C++ for-init names in the same function.
    t=t.replace('for (size_t i = 0; i < characterCount; i++)', 'for (size_t scanIndex = 0; scanIndex < characterCount; scanIndex++)')

    # Core package callbacks from the public package descriptor; only their
    # function-pointer shapes are needed by the core package manager.
    if 'RexxPackageLoader' in t and 'typedef void (*RexxPackageLoader)' not in t:
        t=t.replace('class LibraryLoaderDispatcher', 'typedef void (*RexxPackageLoader)(RexxThreadContext *);\ntypedef void (*RexxPackageUnloader)(RexxThreadContext *);\nclass LibraryLoaderDispatcher', 1)

    # Shared variable block shape required because InterpreterInstance dereferences it.
    if 'PSHVBLOCK' in t and 'typedef struct _SHVBLOCK' not in t:
        shv = 'typedef struct _SHVBLOCK { struct _SHVBLOCK *shvnext; CONSTRXSTRING shvname; RXSTRING shvvalue; size_t shvnamelen; size_t shvvaluelen; unsigned char shvcode; unsigned char shvret; } SHVBLOCK;\ntypedef SHVBLOCK *PSHVBLOCK;\n'
        t=t.replace('class NativeActivation', shv+'class NativeActivation', 1)

    # Expand target platform service declarations used by the core.
    t=t.replace('class SystemInterpreter { public: static void initialize(){} static void terminate(){} static void *allocateResultMemory(size_t); static void releaseResultMemory(void *); };',
      'class FileNameBuffer; class SystemInterpreter { public: static void initialize(){} static void terminate(){} static void *allocateResultMemory(size_t); static void releaseResultMemory(void *); static void *allocateSegmentMemory(size_t); static void releaseSegmentMemory(void *); static void restoreEnvironment(void *); static int getEnvironmentVariable(const char *, FileNameBuffer &); };')
    t=t.replace("class SysFileSystem {\npublic:\n    static const char PathDelimiter='.';\n    static const char PathSeparator=';';\n};",
      "class SysFileSystem { public: enum { PathDelimiter='.', PathSeparator=';' }; static int primitiveSearchName(const char *, const char *, const char *, FileNameBuffer &); static int isCaseSensitive(const char *); };")
    t=t.replace('class SysFile { public: SysFile() {} };',
      'class SysFile { public: SysFile() {} int open(const char *, int, int, int); int open(FileNameBuffer &, int, int, int); int read(char *, size_t, size_t &); int write(const char *, size_t, size_t &); int close(); };')

    # Host va_start is not an S/370 ABI. Keep it as an explicit target seam.
    if '/(args, message);' in t:
        t=t.replace('static void logMemoryCheck', 'void mvs_va_start(va_list *, const void *);\nstatic void logMemoryCheck', 1)
        t=t.replace('/(args, message);','mvs_va_start(&args, &message);')

    t=t.replace('class SysProcess { public: SysProcess() {} };', 'class SysProcess { public: SysProcess() {} static const char *getLibraryLocation(); };')
    # Memory/platform facade details needed by RexxMemory.  These are target
    # contracts, not Unix semantics; MVS implementations bind them later.
    if 'class FileNameBuffer;' in t and 'class FileNameBuffer {' not in t:
        fb = 'class FileNameBuffer { public: FileNameBuffer(size_t initial=0); FileNameBuffer(const char *); FileNameBuffer(const FileNameBuffer &); ~FileNameBuffer(); FileNameBuffer &operator=(const char *); FileNameBuffer &operator+=(const char *); operator char *(); operator const char *(); protected: char *buffer; size_t bufferSize; };'
        t=t.replace('class FileNameBuffer;', fb, 1)
    t=t.replace('static void restoreEnvironment(void *); static int getEnvironmentVariable', 'static void restoreEnvironment(void *); static void live(size_t); static void liveGeneral(int); static int getEnvironmentVariable')
    # Stable abstract MVS file flags for the target SysFile layer.
    for sym,val in [('RX_O_RDONLY','1'),('RX_O_CREAT','2'),('RX_O_TRUNC','4'),('RX_O_WRONLY','8'),('RX_S_IREAD','16'),('RX_S_IWRITE','32'),('RX_SH_DENYWR','64'),('RX_SH_DENYRW','128')]:
        t=re.sub(r'\b'+sym+r'\b', val, t)
    t=t.replace('BASEIMAGE', '"rexx.img"')
    if 'malloc(' in t and 'void *malloc(' not in t:
        t='void *malloc(unsigned int);\n'+t
    t=t.replace('vprintf(message, args);','vprintf((char *)message, args);')
    t=t.replace('vfprintf(outfile, message, args);','vfprintf(outfile, (char *)message, args);')
    if 'va_end(args);' in t:
        t=t.replace('void mvs_va_start(va_list *, const void *);', 'void mvs_va_start(va_list *, const void *); void mvs_va_end(va_list *);')
        t=t.replace('va_end(args);','mvs_va_end(&args);')

    # line ending and MemorySegment array address.  Use a literal backslash-n;
    # re.sub replacement syntax would otherwise insert a physical newline.
    t=t.replace('line_end', '"\\n"')
    t=t.replace('fwrite(&segmentStart, 1, segmentSize, dumpfile);','fwrite((const char *)&segmentStart, 1, segmentSize, dumpfile);')

    # LanguageParser C++98 for-scope and macro-space declaration.
    old='for (size_t i = 1; i <= classCount; i++)\n            {\n                ClassDirective *currentClass = (ClassDirective *)classes->get(i);\n                if (currentClass->dependenciesResolved())'
    new='for (size_t j = 1; j <= classCount; j++)\n            {\n                ClassDirective *currentClass = (ClassDirective *)classes->get(j);\n                if (currentClass->dependenciesResolved())'
    if old in t:
        t=t.replace(old,new,1); t=t.replace('classes->deleteItem(i);','classes->deleteItem(j);',1)
    old='for (size_t i = 1; i <= classCount; i++)\n            {\n                ClassDirective *currentClass = (ClassDirective *)classes->get(i);\n                currentClass->removeDependency(className);'
    new='for (size_t k = 1; k <= classCount; k++)\n            {\n                ClassDirective *currentClass = (ClassDirective *)classes->get(k);\n                currentClass->removeDependency(className);'
    t=t.replace(old,new,1)
    if 'RexxQueryMacro(' in t and 'RexxReturnCode RexxQueryMacro(' not in t:
        t='extern "C" { int RexxQueryMacro(const char *, unsigned short *); }\n'+t

    if 'snprintf(' in t and 'int snprintf(char *, unsigned int, const char *, ...);' not in t:
        t='int snprintf(char *, unsigned int, const char *, ...);\n'+t

    # automatic aggregate empty string; calling convention marker.
    t=re.sub(r'char\s+([A-Za-z_]\w*)\[(\d+)\]\s*=\s*""\s*;', r'char \1[\2]; \1[0] = 0;', t)
    t=re.sub(r'\bRexxEntry\b','',t)

    (root/p.name).write_text(t)
from pathlib import Path
import re,sys
root=Path(sys.argv[1])
EH='''\ntypedef int MvsJmpBuf[32];\nextern "C" int setjmp(MvsJmpBuf);\nextern "C" void longjmp(MvsJmpBuf, int);\nstruct MvsUnwindFrame { MvsJmpBuf env; MvsUnwindFrame *previous; void *object; int type; };\nenum { MVS_UNWIND_REXX_ACTIVATION = 1, MVS_UNWIND_NATIVE_ACTIVATION = 2 };\nvoid mvsUnwindPush(MvsUnwindFrame *, int);\nvoid mvsUnwindPop(MvsUnwindFrame *);\nvoid mvsUnwindRaise(int, void *);\n'''

def block(text, start, end):
    a=text.find(start)
    if a<0: raise RuntimeError('start not found '+start)
    b=text.find(end,a)
    if b<0: raise RuntimeError('end not found '+end)
    return a,b,text[a:b]

for p in root.glob('*.ii'):
    t=p.read_text(errors='ignore')
    name=p.name
    if name=='interpreter_execution_RexxActivation_cpp.ii':
        t=EH+t
        # platform/API seams still missing in dev12.
        t=t.replace('class FileNameBuffer; class SystemInterpreter { public:', 'class FileNameBuffer; class RexxDateTime; class SystemInterpreter { public:')
        t=t.replace('static int getEnvironmentVariable(const char *, FileNameBuffer &); };',
                    'static int getEnvironmentVariable(const char *, FileNameBuffer &); static int invokeExternalFunction(RexxActivation *, Activity *, RexxString *, RexxObject **, size_t, RexxString *, ProtectedObject &); static void getCurrentTime(RexxDateTime *); static const char *getPlatformName(); static RexxString *getDefaultAddressName(); };')
        # If RexxActivation forward decls made the previous insertion too early, declarations below are enough for old lookup.
        if 'class SysFileSystem {' not in t:
            t='class SysFileSystem { public: static int isCaseSensitive(); };\n'+t
        else:
            t=re.sub(r'class SysFileSystem \{ public:([^}]*)\};', lambda m:'class SysFileSystem { public:'+m.group(1)+' static int isCaseSensitive(); };', t, count=1)
        t=t.replace('if (routine == 0)', 'if (routine.isNull())')
        t=t.replace('NULLOBJECT', '0')
        t=t.replace('RXSUBCOM_NOTREG', '1')
        # Inline function with static local exceeds cfront expander: make it out-of-line.
        t=t.replace('inline RexxClass *getRexxPackageTraceObject()', 'RexxClass *getRexxPackageTraceObject()')

        # run(): replace C++ EH with explicit MVS SJLJ frame.
        a,b,s=block(t,'RexxObject* RexxActivation::run(', '\nint RexxActivation::processTraps()')
        s=s.replace('    exception_ptr ex;\n    while (1)\n    {\n        ex = 0;\n        try\n        {',
'''    while (1)\n    {\n        MvsUnwindFrame mvsFrame;\n        mvsUnwindPush(&mvsFrame, MVS_UNWIND_REXX_ACTIVATION);\n        if (setjmp(mvsFrame.env) == 0)\n        {''',1)
        s=s.replace('            return resultObj;\n        }\n        catch (const RexxActivation *t)\n        {',
'''            mvsUnwindPop(&mvsFrame);\n            return resultObj;\n        }\n        else\n        {\n            const RexxActivation *t = (const RexxActivation *)mvsFrame.object;\n            mvsUnwindPop(&mvsFrame);''',1)
        s=s.replace('            if (t != this)\n            {\n                ex = current_exception();\n            }',
'''            if (t != this)\n            {\n                mvsUnwindRaise(MVS_UNWIND_REXX_ACTIVATION, (void *)t);\n            }''',1)
        s=s.replace('        if (ex)\n        {\n            rethrow_exception(ex);\n        }\n','',1)
        t=t[:a]+s+t[b:]

        # processTraps(): local catch becomes local SJLJ frame.
        a,b,s=block(t,'int RexxActivation::processTraps()', '\nvoid RexxActivation::debugSkip(')
        s=s.replace('    exception_ptr ex;\n','',1)
        s=s.replace('            ex = 0;\n            try\n            {\n                trapHandler->trap(this);\n            }\n            catch (RexxActivation *t)\n            {',
'''            MvsUnwindFrame mvsFrame;\n            mvsUnwindPush(&mvsFrame, MVS_UNWIND_REXX_ACTIVATION);\n            if (setjmp(mvsFrame.env) == 0)\n            {\n                trapHandler->trap(this);\n                mvsUnwindPop(&mvsFrame);\n            }\n            else\n            {\n                RexxActivation *t = (RexxActivation *)mvsFrame.object;\n                mvsUnwindPop(&mvsFrame);''',1)
        s=s.replace('                if (t != this)\n                {\n                    ex = current_exception();\n                }',
'''                if (t != this)\n                {\n                    mvsUnwindRaise(MVS_UNWIND_REXX_ACTIVATION, (void *)t);\n                }''',1)
        s=s.replace('            if (ex)\n            {\n                rethrow_exception(ex);\n            }\n','',1)
        t=t[:a]+s+t[b:]

        # debugInterpret().
        a,b,s=block(t,'void RexxActivation::debugInterpret(', '\nRexxObject * RexxActivation::rexxVariable(')
        s=s.replace('    exception_ptr ex;\n    try\n    {',
'''    MvsUnwindFrame mvsFrame;\n    mvsUnwindPush(&mvsFrame, MVS_UNWIND_REXX_ACTIVATION);\n    if (setjmp(mvsFrame.env) == 0)\n    {''',1)
        s=s.replace('        debugPause = 0;\n    }\n    catch (RexxActivation *t)\n    {',
'''        debugPause = 0;\n        mvsUnwindPop(&mvsFrame);\n    }\n    else\n    {\n        RexxActivation *t = (RexxActivation *)mvsFrame.object;\n        mvsUnwindPop(&mvsFrame);''',1)
        s=s.replace('        if (t != this)\n        {\n            ex = current_exception();\n        }',
'''        if (t != this)\n        {\n            mvsUnwindRaise(MVS_UNWIND_REXX_ACTIVATION, (void *)t);\n        }''',1)
        s=s.replace('    if (ex)\n    {\n        rethrow_exception(ex);\n    }\n','',1)
        t=t[:a]+s+t[b:]
        # All RexxActivation pointer throws become the MVS unwind primitive.
        t=t.replace('throw this;', 'mvsUnwindRaise(MVS_UNWIND_REXX_ACTIVATION, (void *)this);')
        t=t.replace('throw activation;', 'mvsUnwindRaise(MVS_UNWIND_REXX_ACTIVATION, (void *)activation);')

    elif name=='interpreter_runtime_InterpreterInstance_cpp.ii':
        t=EH+t
        # internal API facade completion
        t=t.replace('struct RexxInstance {\n    void *functions;\n};','struct RexxInstance {\n    void *functions;\n    void *applicationData;\n};')
        t=t.replace('class SysActivity { public: SysActivity() {} int equals(unsigned long) { return 0; } void create(Activity *) {} void terminate() {} };',
                    'class SysActivity { public: SysActivity() {} int equals(unsigned long) { return 0; } void create(Activity *) {} void terminate() {} static unsigned long queryThreadID(); };')
        t=t.replace('class FileNameBuffer; class SystemInterpreter { public:', 'class FileNameBuffer; class RexxString; class SystemInterpreter { public:')
        t=t.replace('static int getEnvironmentVariable(const char *, FileNameBuffer &); };',
                    'static int getEnvironmentVariable(const char *, FileNameBuffer &); static RexxString *getDefaultAddressName(); };')
        t=t.replace('class SysSearchPath {\npublic:\n    SysSearchPath(const char *, const char *);',
                    'class SysSearchPath {\npublic:\n    const char *path;\n    SysSearchPath(const char *, const char *);')
        # Complete target filesystem contract here; no Unix semantics.
        insert='class FileNameBuffer; class SysFileSystem { public: static int hasExtension(const char *); static int searchName(const char *, const char *, const char *, FileNameBuffer &); };\n'
        if 'class SysFileSystem {' not in t: t=insert+t
        t=t.replace('RXENDLST','-1')

        a,b,s=block(t,'int InterpreterInstance::terminate()', '\nvoid InterpreterInstance::addGlobalReference(')
        s=s.replace('    Activity *current;\n    int activityCreated = 0;\n    try\n    {',
'''    Activity *current = 0;\n    int activityCreated = 0;\n    MvsUnwindFrame mvsFrame;\n    mvsUnwindPush(&mvsFrame, MVS_UNWIND_NATIVE_ACTIVATION);\n    if (setjmp(mvsFrame.env) == 0)\n    {''',1)
        s=s.replace('        current->exitCurrentThread(0);\n    }\n    catch (NativeActivation *)\n    {',
'''        current->exitCurrentThread(0);\n        mvsUnwindPop(&mvsFrame);\n    }\n    else\n    {\n        mvsUnwindPop(&mvsFrame);''',1)
        t=t[:a]+s+t[b:]

    (root/p.name).write_text(t)
