#!/usr/bin/env bash
set -u

CFRONT_SRC="${CFRONT_SRC:-/tmp/cfront-src}"
OOREXX_SRC="${OOREXX_SRC:-/tmp/oorexx-src}"
WORK="${WORK:-/tmp/oorexx-mvs24-cfront-bulkpass-dev15}"
PIN="${PIN:-de1db87f486d430d1faa9151b8a2d5f328ab70f2}"

mkdir -p "$WORK"/{mvs,compat,preprocessed,shadow,logs,reports}
rm -f "$WORK"/preprocessed/* "$WORK"/shadow/* "$WORK"/logs/* "$WORK"/reports/* 2>/dev/null || true

say() { printf '\n==== %s ====\n' "$*"; }

SWEEP_MODE="${SWEEP_MODE:-representative}"

REPRESENTATIVE_FILES="
interpreter/classes/ObjectClass.cpp
interpreter/classes/ClassClass.cpp
interpreter/classes/StringClass.cpp
interpreter/classes/IntegerClass.cpp
interpreter/classes/NumberStringClass.cpp
interpreter/classes/ArrayClass.cpp
interpreter/classes/ListClass.cpp
interpreter/classes/QueueClass.cpp
interpreter/classes/DirectoryClass.cpp
interpreter/classes/TableClass.cpp
interpreter/classes/MutableBufferClass.cpp
interpreter/classes/support/HashCollection.cpp
interpreter/classes/support/HashContents.cpp
interpreter/memory/RexxMemory.cpp
interpreter/memory/MemorySegment.cpp
interpreter/memory/MemoryStack.cpp
interpreter/memory/InternalStack.cpp
interpreter/memory/MapBucket.cpp
interpreter/memory/PointerBucket.cpp
interpreter/memory/NumberArray.cpp
interpreter/execution/RexxActivation.cpp
interpreter/execution/VariableDictionary.cpp
interpreter/parser/Scanner.cpp
interpreter/parser/LanguageParser.cpp
interpreter/parser/Clause.cpp
interpreter/runtime/InterpreterInstance.cpp
"

if [ "$SWEEP_MODE" = "all" ]; then
    FILES="$(python3 - "$OOREXX_SRC" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
roots=[root/"common",root/"interpreter",root/"api",root/"lib"]
for base in roots:
    if not base.exists():
        continue
    for p in sorted(base.rglob("*.cpp")):
        rel=p.relative_to(root).as_posix()
        parts=rel.split("/")
        if (
            rel.startswith(("extensions/","samples/","rexxapi/","utilities/","testbinaries/"))
            or "platform" in parts or "windows" in parts or "unix" in parts or "oodialog" in parts
        ):
            continue
        print(rel)
PY
)"
else
    FILES="$REPRESENTATIVE_FILES"
fi

say "0. Verify source pins"
[ -d "$OOREXX_SRC/.git" ] || { echo "Missing ooRexx checkout"; exit 20; }
git -C "$OOREXX_SRC" checkout --detach "$PIN" >/dev/null || exit 21
CFRONT="$CFRONT_SRC/cfront"
[ -x "$CFRONT" ] || { echo "Missing cfront"; exit 22; }

CC370_SRC="${CC370_SRC:-/tmp/cc370-src}"
XGCC="$CC370_SRC/build/gcc/xgcc"

printf 'oorexx_commit=%s\n' "$(git -C "$OOREXX_SRC" rev-parse HEAD)"
printf 'cfront_commit=%s\n' "$(git -C "$CFRONT_SRC" rev-parse HEAD 2>/dev/null || echo unknown)"

# cfront cross-target data model: System/370 storage containers are 32-bit;
# MVS 3.8J effective addressability remains 24-bit and is audited separately.
cat >"$WORK/mvs370.size" <<'EOF'
#define DBI_IN_WORD 32
#define DBI_IN_BYTE 8
#define DSZ_CHAR 1
#define DAL_CHAR 1
#define DSZ_SHORT 2
#define DAL_SHORT 2
#define DSZ_INT 4
#define DAL_INT 4
#define DLARGEST_INT "2147483647"
#define DSZ_LONG 4
#define DAL_LONG 4
#define DSZ_LLONG 8
#define DAL_LLONG 4
#define DSZ_FLOAT 4
#define DAL_FLOAT 4
#define DSZ_DOUBLE 8
#define DAL_DOUBLE 8
#define DSZ_LDOUBLE 8
#define DAL_LDOUBLE 8
#define DSZ_STRUCT 1
#define DAL_STRUCT 1
#define DF_SENSITIVE 0
#define DF_OPTIMIZED 1
#define DSZ_WORD 4
#define DSZ_WPTR 4
#define DAL_WPTR 4
#define DSZ_BPTR 4
#define DAL_BPTR 4
EOF
CFRONT_XFLAG="+x$WORK/mvs370.size"

say "1. Platform-neutral core include set"
python3 - "$OOREXX_SRC" "$WORK/reports/include_dirs.txt" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]); out=Path(sys.argv[2])
allowed=[root/"lib",root/"common",root/"interpreter",root/"api"]
def reject(p):
    rel=p.relative_to(root).as_posix()
    parts=rel.split("/")
    return (
        rel.startswith(("extensions/","samples/","rexxapi/","utilities/","testbinaries/"))
        or "platform" in parts or "windows" in parts or "oodialog" in parts
    )
dirs=set()
for base in allowed:
    if not base.exists(): continue
    for p in base.rglob("*"):
        if reject(p): continue
        if p.is_file() and p.suffix.lower() in {".h",".hpp",".hh",".hxx"}:
            dirs.add(str(p.parent))
def rank(s):
    rel=Path(s).relative_to(root).as_posix()
    if rel=="lib": return (0,rel)
    if rel=="common": return (1,rel)
    if rel.startswith("interpreter"): return (2,rel)
    if rel.startswith("api"): return (3,rel)
    return (9,rel)
items=sorted(dirs,key=rank)
out.write_text("\n".join(items)+"\n")
print("include_dirs",len(items))
for x in items: print(x)
PY

say "2. Whole-core compatibility and MVS24 census"

python3 - "$OOREXX_SRC" "$WORK/reports" <<'PY'
from pathlib import Path
import re, sys, json

root=Path(sys.argv[1]); out=Path(sys.argv[2])
allowed=[root/"common", root/"interpreter", root/"api", root/"lib"]

def allowed_file(p):
    rel=p.relative_to(root).as_posix()
    parts=rel.split("/")
    if rel.startswith(("extensions/","samples/","rexxapi/","utilities/","testbinaries/")):
        return False
    if "platform" in parts or "windows" in parts or "unix" in parts or "oodialog" in parts:
        return False
    return p.suffix.lower() in {".h",".hpp",".hh",".hxx",".c",".cc",".cpp",".cxx"}

patterns = {
    "class_operator_new_extra": re.compile(r'operator\s+new\s*\(\s*size_t\s+[^,\)]*\s*,'),
    "placement_new": re.compile(r'\bnew\s*\([^;\n]+\)\s+[A-Za-z_]\w*'),
    "static_const_integral_init": re.compile(r'static\s+const\s+(?:size_t|int|long|unsigned(?:\s+long|\s+int)?|char|uint(?:8|16|32|64)_t|int(?:8|16|32|64)_t|wholenumber_t)\s+\w+\s*='),
    "default_argument": re.compile(r'\([^;\n]*=\s*[A-Za-z_]\w*[^;\n]*\)'),
    "flagset": re.compile(r'\bFlagSet\s*<'),
    "bitset": re.compile(r'\bBitSet\s*<'),
    "atomic": re.compile(r'\bstd::atomic\s*<'),
    "exception_ptr": re.compile(r'\bstd::exception_ptr\b'),
    "deleted_defaulted": re.compile(r'=\s*(?:delete|default)\s*;'),
    "uintptr_use": re.compile(r'\b(?:u?intptr_t)\b'),
    "pointer_integer_cast": re.compile(r'\(\s*(?:u?intptr_t|size_t|unsigned\s+long|long)\s*\)\s*[A-Za-z_]\w*'),
    "large_shift": re.compile(r'\b1\s*<<\s*(?:2[4-9]|3[0-1])\b'),
}

hits={k:[] for k in patterns}
files=0
for base in allowed:
    if not base.exists(): continue
    for p in base.rglob("*"):
        if not p.is_file() or not allowed_file(p): continue
        files += 1
        try: data=p.read_text(errors="ignore")
        except Exception: continue
        rel=p.relative_to(root).as_posix()
        for name,rx in patterns.items():
            for m in rx.finditer(data):
                line=data.count("\n",0,m.start())+1
                frag=data[m.start():data.find("\n",m.start()) if data.find("\n",m.start())>=0 else m.end()+120].strip()
                hits[name].append((rel,line,frag[:220]))

with (out/"compatibility-census.tsv").open("w") as f:
    f.write("family\tfile\tline\tfragment\n")
    for family in sorted(hits):
        for rel,line,frag in hits[family]:
            f.write(f"{family}\t{rel}\t{line}\t{frag}\n")

summary={k:len(v) for k,v in hits.items()}
summary["files_scanned"]=files
(out/"compatibility-census.json").write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")

# 24-bit-specific audit: this is deliberately an audit, not a claim that
# pointer containers are 24 bits wide.
with (out/"mvs24-audit.txt").open("w") as f:
    f.write("MVS 3.8J ADDRESS MODEL\n")
    f.write("effective_address_bits=24\n")
    f.write("effective_address_mask=0x00ffffff\n")
    f.write("virtual_address_ceiling_bytes=16777216\n")
    f.write("pointer_container_width=QUALIFY_WITH_CC370\n")
    f.write("size_t_width=QUALIFY_WITH_CC370\n\n")
    for family in ("uintptr_use","pointer_integer_cast","large_shift","class_operator_new_extra","placement_new"):
        f.write(f"[{family}] count={len(hits[family])}\n")
        for rel,line,frag in hits[family][:200]:
            f.write(f"{rel}:{line}: {frag}\n")
        f.write("\n")

print("core_files_scanned", files)
for k in sorted(summary):
    if k!="files_scanned":
        print(f"census_{k}={summary[k]}")
PY

say "3. MVS primitive/platform facade"

cat >"$WORK/mvs/PlatformDefinitions.h" <<'EOF'
#ifndef RX_MVS_PLATFORM_DEFINITIONS_H
#define RX_MVS_PLATFORM_DEFINITIONS_H
#define RX_MVS 1

typedef unsigned int size_t;
typedef long ssize_t;
typedef long ptrdiff_t;
typedef unsigned long uintptr_t;
typedef long intptr_t;

typedef unsigned long uint32_t;
typedef unsigned short uint16_t;
typedef unsigned char uint8_t;
typedef long int32_t;
typedef short int16_t;
typedef signed char int8_t;

typedef unsigned long long uint64_t;
typedef long long int64_t;

typedef unsigned long thread_id_t;
typedef unsigned long process_id_t;

/*
 * MVS 3.8J target model:
 *   - System/370 32-bit registers / integer operations
 *   - 24-bit effective addressing (16 MiB virtual address ceiling)
 * The C pointer container width is a compiler ABI property and is qualified
 * separately; it must not be confused with effective address width.
 */
#define RX_MVS24_EFFECTIVE_ADDRESS_BITS 24
#define RX_MVS24_ADDRESS_MASK 0x00ffffffUL

/* 32-bit integer/container limits where the cc370/cfront ABI uses them. */
#ifndef UINT32_MAX
#define UINT32_MAX 4294967295UL
#endif
#ifndef INT32_MAX
#define INT32_MAX 2147483647L
#endif
#ifndef INT32_MIN
#define INT32_MIN (-2147483647L - 1L)
#endif
#ifndef UINTPTR_MAX
#define UINTPTR_MAX 4294967295UL
#define INT64_MAX 9223372036854775807LL
#define INT64_MIN (-9223372036854775807LL - 1LL)
#define UINT64_MAX 18446744073709551615ULL
#endif
#ifndef INTPTR_MAX
#define INTPTR_MAX 2147483647L
#endif
#ifndef INTPTR_MIN
#define INTPTR_MIN (-2147483647L - 1L)
#endif
#ifndef SIZE_MAX
#define SIZE_MAX 4294967295UL
#endif
#ifndef RX_MVS24_EFFECTIVE_ADDRESS_BITS
#define RX_MVS24_EFFECTIVE_ADDRESS_BITS 24
#endif
#ifndef RX_MVS24_ADDRESS_MASK
#define RX_MVS24_ADDRESS_MASK 0x00ffffffUL
#endif

#ifndef NULL
#define NULL 0
#endif
#ifndef PATH_MAX
#define PATH_MAX 255
#endif
#endif
EOF

cat >"$WORK/mvs/APIDefinitions.h" <<'EOF'
#ifndef RX_MVS_API_DEFINITIONS_H
#define RX_MVS_API_DEFINITIONS_H
#define REXXENTRY
#define REXXEXPORT
#define REXXIMPORT
#define REXXSHARED
#endif
EOF

cat >"$WORK/mvs/rexxapitypes.h" <<'EOF'
#ifndef RX_MVS_REXX_API_TYPES_H
#define RX_MVS_REXX_API_TYPES_H
typedef unsigned int size_t;
typedef long ssize_t;
typedef unsigned long uintptr_t;
typedef long intptr_t;
typedef unsigned long uint32_t;
typedef unsigned short uint16_t;
typedef unsigned char uint8_t;
typedef long int32_t;
typedef short int16_t;
typedef signed char int8_t;
typedef unsigned long long uint64_t;
typedef long long int64_t;

#ifndef UINT32_MAX
#define UINT32_MAX 4294967295UL
#endif
#ifndef INT32_MAX
#define INT32_MAX 2147483647L
#endif
#ifndef INT32_MIN
#define INT32_MIN (-2147483647L - 1L)
#endif
#ifndef UINTPTR_MAX
#define UINTPTR_MAX 4294967295UL
#endif
#ifndef INTPTR_MAX
#define INTPTR_MAX 2147483647L
#endif
#ifndef INTPTR_MIN
#define INTPTR_MIN (-2147483647L - 1L)
#endif
#ifndef SIZE_MAX
#define SIZE_MAX 4294967295UL
#endif
#endif
EOF

cat >"$WORK/mvs/rexxplatformdefs.h" <<'EOF'
#ifndef RX_MVS_REXX_PLATFORM_DEFS_H
#define RX_MVS_REXX_PLATFORM_DEFS_H
#define REXXENTRY
#define REXXEXPORT
#define REXXIMPORT
#endif
EOF

cat >"$WORK/mvs/rexxplatformapis.h" <<'EOF'
#ifndef RX_MVS_REXX_PLATFORM_APIS_H
#define RX_MVS_REXX_PLATFORM_APIS_H
#endif
EOF

cat >"$WORK/mvs/SysInterpreterInstance.hpp" <<'EOF'
#ifndef RX_MVS_SYS_INTERPRETER_INSTANCE_HPP
#define RX_MVS_SYS_INTERPRETER_INSTANCE_HPP
class InterpreterInstance;
class RexxActivation;
class RexxOption;
class SysInterpreterInstance {
public:
    void live(size_t);
    void liveGeneral(int);
    void initialize(InterpreterInstance *, RexxOption *);
    void terminate();
    void registerCommandHandlers(InterpreterInstance *);
    void setupProgram(RexxActivation *);
};
class SysSearchPath {
public:
    SysSearchPath(const char *, const char *);
    ~SysSearchPath() {}
    void addPath(const char *) {}
};
#endif
EOF

cat >"$WORK/mvs/SysActivity.hpp" <<'EOF'
#ifndef RX_MVS_SYS_ACTIVITY_HPP
#define RX_MVS_SYS_ACTIVITY_HPP
class Activity;
class SysActivity {
public:
    SysActivity() {}
    void create(Activity *) {}
    void terminate() {}
};
#endif
EOF

cat >"$WORK/mvs/SysFileSystem.hpp" <<'EOF'
#ifndef RX_MVS_SYS_FILE_SYSTEM_HPP
#define RX_MVS_SYS_FILE_SYSTEM_HPP
class FileNameBuffer;
class SysFileSystem {
public:
    static const char PathDelimiter='.';
    static const char PathSeparator=';';
};
#endif
EOF

cat >"$WORK/mvs/SystemInterpreter.hpp" <<'EOF'
#ifndef RX_MVS_SYSTEM_INTERPRETER_HPP
#define RX_MVS_SYSTEM_INTERPRETER_HPP
class SystemInterpreter {
public:
    static void initialize() {}
    static void terminate() {}
};
#endif
EOF

cat >"$WORK/mvs/SysSemaphore.hpp" <<'EOF'
#ifndef RX_MVS_SYS_SEMAPHORE_HPP
#define RX_MVS_SYS_SEMAPHORE_HPP
class SysMutex {
public:
    SysMutex() {}
    void create(int = 0) {}
    int request() { return 1; }
    void release() {}
    void close() {}
};
class SysSemaphore { public: SysSemaphore() {} };
#endif
EOF
for h in SysFile SysLibrary SysProcess SysThread; do
cat >"$WORK/mvs/$h.hpp" <<EOF
#ifndef RX_MVS_${h}_HPP
#define RX_MVS_${h}_HPP
class $h { public: $h() {} };
#endif
EOF
done

# MVS has no built-in native extension list at bootstrap.  These headers are
# deliberately empty so core package-list TUs do not pull Unix/Windows code.
for h in SysNativeMethods SysNativeFunctions SysRexxUtilFunctions; do
cat >"$WORK/mvs/$h.h" <<EOF
#ifndef RX_MVS_${h}_H
#define RX_MVS_${h}_H
#endif
EOF
done

say "4. INTERNAL ooRexx ABI facade -- deliberately not the public API"

cat >"$WORK/mvs/rexx.h" <<'EOF'
#ifndef RX_MVS_INTERNAL_REXX_H
#define RX_MVS_INTERNAL_REXX_H

#include "rexxapitypes.h"
#include "rexxplatformdefs.h"

#ifndef NULL
#define NULL 0
#endif

#define BEGIN_EXTERN_C()
#define END_EXTERN_C()

typedef int RexxReturnCode;
typedef const char *CSTRING;
typedef void *POINTER;

typedef size_t stringsize_t;
typedef ssize_t wholenumber_t;
typedef size_t logical_t;

class _RexxObjectPtr {};
class _RexxStringObject : public _RexxObjectPtr {};
class _RexxBufferStringObject : public _RexxStringObject {};
class _RexxArrayObject : public _RexxObjectPtr {};
class _RexxBufferObject : public _RexxObjectPtr {};
class _RexxPointerObject : public _RexxObjectPtr {};
class _RexxMethodObject : public _RexxObjectPtr {};
class _RexxRoutineObject : public _RexxObjectPtr {};
class _RexxPackageObject : public _RexxObjectPtr {};
class _RexxClassObject : public _RexxObjectPtr {};
class _RexxDirectoryObject : public _RexxObjectPtr {};
class _RexxStringTableObject : public _RexxObjectPtr {};
class _RexxSupplierObject : public _RexxObjectPtr {};
class _RexxStemObject : public _RexxObjectPtr {};
class _RexxMutableBufferObject : public _RexxObjectPtr {};
class _RexxVariableReferenceObject : public _RexxObjectPtr {};

typedef _RexxObjectPtr *RexxObjectPtr;
typedef _RexxStringObject *RexxStringObject;
typedef _RexxBufferStringObject *RexxBufferStringObject;
typedef _RexxArrayObject *RexxArrayObject;
typedef _RexxBufferObject *RexxBufferObject;
typedef _RexxPointerObject *RexxPointerObject;
typedef _RexxMethodObject *RexxMethodObject;
typedef _RexxRoutineObject *RexxRoutineObject;
typedef _RexxPackageObject *RexxPackageObject;
typedef _RexxClassObject *RexxClassObject;
typedef _RexxDirectoryObject *RexxDirectoryObject;
typedef _RexxStringTableObject *RexxStringTableObject;
typedef _RexxSupplierObject *RexxSupplierObject;
typedef _RexxStemObject *RexxStemObject;
typedef _RexxMutableBufferObject *RexxMutableBufferObject;
typedef _RexxVariableReferenceObject *RexxVariableReferenceObject;

struct RXSTRING {
    size_t strlength;
    char *strptr;
};
typedef struct RXSTRING RXSTRING;
typedef RXSTRING *PRXSTRING;

struct CONSTRXSTRING {
    size_t strlength;
    const char *strptr;
};
typedef struct CONSTRXSTRING CONSTRXSTRING;
typedef CONSTRXSTRING *PCONSTRXSTRING;

struct RXSYSEXIT {
    CSTRING sysexit_name;
    int sysexit_code;
};
typedef struct RXSYSEXIT RXSYSEXIT;
typedef RXSYSEXIT *PRXSYSEXIT;

typedef char *PEXIT;

typedef size_t (*REXXPFN)();

#define DEFRXSTRING 256

struct RexxInstance;
struct RexxThreadContext;
struct RexxMethodContext;
struct RexxCallContext;
struct RexxExitContext;
struct RexxIORedirectorContext;

struct RexxInstance {
    void *functions;
};

struct RexxThreadContext {
    RexxInstance *instance;
    void *functions;
};

struct RexxMethodContext {
    RexxThreadContext *threadContext;
    void *functions;
};

struct RexxCallContext {
    RexxThreadContext *threadContext;
    void *functions;
};

struct RexxExitContext {
    RexxThreadContext *threadContext;
    void *functions;
};

struct RexxIORedirectorContext {
    RexxThreadContext *threadContext;
    void *functions;
};

typedef int RexxContextExitHandler(RexxExitContext *, int, int, PEXIT);

struct RexxContextExit {
    RexxContextExitHandler *handler;
    int sysexit_code;
};

struct RexxRoutineEntry {
    int style;
    int reserved1;
    const char *name;
    void *entryPoint;
    int reserved2;
    int reserved3;
};

struct RexxMethodEntry {
    int style;
    int reserved1;
    const char *name;
    void *entryPoint;
    int reserved2;
    int reserved3;
};

struct RexxPackageEntry {
    int size;
    int apiVersion;
    int requiredVersion;
    const char *packageName;
    const char *packageVersion;
    void *loader;
    void *unloader;
    RexxRoutineEntry *routines;
    RexxMethodEntry *methods;
};

struct RexxConditionData {
    wholenumber_t code;
    wholenumber_t rc;
    RXSTRING message;
    RXSTRING errortext;
    size_t position;
    RXSTRING program;
};

struct RexxCondition {
    wholenumber_t code;
    wholenumber_t rc;
    size_t position;
    RexxStringObject conditionName;
    RexxStringObject message;
    RexxStringObject errortext;
    RexxStringObject program;
    RexxStringObject description;
    RexxArrayObject additional;
};

/* Minimal classic exit records needed by interpreter declarations. */
struct RXFNC_FLAGS {
    unsigned rxfferr:1;
    unsigned rxffnfnd:1;
    unsigned rxffsub:1;
};

struct RXFNCCAL_PARM {
    RXFNC_FLAGS rxfnc_flags;
    CSTRING rxfnc_name;
    unsigned short rxfnc_namel;
    CSTRING rxfnc_que;
    unsigned short rxfnc_quel;
    unsigned short rxfnc_argc;
    PCONSTRXSTRING rxfnc_argv;
    RXSTRING rxfnc_retc;
};

struct RXEXF_FLAGS {
    unsigned rxfferr:1;
    unsigned rxffnfnd:1;
    unsigned rxffsub:1;
};

struct RXEXFCAL_PARM {
    RXEXF_FLAGS rxfnc_flags;
    CONSTRXSTRING rxfnc_name;
    size_t rxfnc_argc;
    RexxObjectPtr *rxfnc_argv;
    RexxObjectPtr rxfnc_retc;
};

struct RXCMD_FLAGS {
    unsigned rxfcfail:1;
    unsigned rxfcerr:1;
};

struct RXCMDHST_PARM {
    RXCMD_FLAGS rxcmd_flags;
    CSTRING rxcmd_address;
    unsigned short rxcmd_addressl;
    CSTRING rxcmd_dll;
    unsigned short rxcmd_dll_len;
    CONSTRXSTRING rxcmd_command;
    RXSTRING rxcmd_retc;
};

#define INITIAL_ADDRESS_ENVIRONMENT "InitialAddress"
#define APPLICATION_DATA "ApplicationData"
#define EXTERNAL_CALL_PATH "ExternalCallPath"
#define EXTERNAL_CALL_EXTENSIONS "ExternalCallPathExt"
#define LOAD_REQUIRED_LIBRARY "LoadRequiredLibrary"
#define REGISTERED_EXITS "RegisteredExits"
#define DIRECT_EXITS "DirectExits"
#define REGISTERED_ENVIRONMENTS "RegisteredEnvironments"
#define DIRECT_ENVIRONMENTS "DirectEnvironments"
#define REDIRECTING_ENVIRONMENTS "RedirectingEnvironments"
#define REGISTER_LIBRARY "RegisterLibrary"

#endif
EOF

cat >"$WORK/mvs/oorexxapi.h" <<'EOF'
#ifndef RX_MVS_INTERNAL_OOREXX_API_H
#define RX_MVS_INTERNAL_OOREXX_API_H

#include "rexx.h"

#define REXX_ARGUMENT_TERMINATOR 0
#define REXX_VALUE_RexxObjectPtr 11
#define REXX_VALUE_int 12
#define REXX_VALUE_wholenumber_t 13
#define REXX_VALUE_double 14
#define REXX_VALUE_CSTRING 15
#define REXX_VALUE_POINTER 16
#define REXX_VALUE_RexxStringObject 17
#define REXX_VALUE_stringsize_t 18
#define REXX_VALUE_float 19
#define REXX_VALUE_int8_t 20
#define REXX_VALUE_int16_t 21
#define REXX_VALUE_int32_t 22
#define REXX_VALUE_int64_t 23
#define REXX_VALUE_uint8_t 24
#define REXX_VALUE_uint16_t 25
#define REXX_VALUE_uint32_t 26
#define REXX_VALUE_uint64_t 27
#define REXX_VALUE_intptr_t 28
#define REXX_VALUE_uintptr_t 29
#define REXX_VALUE_logical_t 30
#define REXX_VALUE_RexxArrayObject 31
#define REXX_VALUE_RexxStemObject 32
#define REXX_VALUE_size_t 33
#define REXX_VALUE_ssize_t 34
#define REXX_VALUE_POINTERSTRING 35
#define REXX_VALUE_RexxClassObject 36
#define REXX_VALUE_RexxMutableBufferObject 37
#define REXX_VALUE_positive_wholenumber_t 38
#define REXX_VALUE_nonnegative_wholenumber_t 39
#define REXX_VALUE_RexxVariableReferenceObject 40

struct ValueDescriptor {
    union {
        RexxObjectPtr value_RexxObjectPtr;
        RexxStringObject value_RexxStringObject;
        RexxArrayObject value_RexxArrayObject;
        RexxStemObject value_RexxStemObject;
        RexxClassObject value_RexxClassObject;
        RexxMutableBufferObject value_RexxMutableBufferObject;
        RexxVariableReferenceObject value_RexxVariableReferenceObject;
        CSTRING value_CSTRING;
        POINTER value_POINTER;
        int value_int;
        wholenumber_t value_wholenumber_t;
        stringsize_t value_stringsize_t;
        logical_t value_logical_t;
        double value_double;
        float value_float;
        size_t value_size_t;
        ssize_t value_ssize_t;
        intptr_t value_intptr_t;
        uintptr_t value_uintptr_t;
        int8_t value_int8_t;
        int16_t value_int16_t;
        int32_t value_int32_t;
        int64_t value_int64_t;
        uint8_t value_uint8_t;
        uint16_t value_uint16_t;
        uint32_t value_uint32_t;
        uint64_t value_uint64_t;
    } value;
    uint16_t type;
    uint16_t flags;

    operator RexxObjectPtr() { return value.value_RexxObjectPtr; }
    void operator=(RexxObjectPtr o) { type=REXX_VALUE_RexxObjectPtr; value.value_RexxObjectPtr=o; }
    operator CSTRING() { return value.value_CSTRING; }
    void operator=(CSTRING o) { type=REXX_VALUE_CSTRING; value.value_CSTRING=o; }
    operator POINTER() { return value.value_POINTER; }
    void operator=(POINTER o) { type=REXX_VALUE_POINTER; value.value_POINTER=o; }
    operator wholenumber_t() { return value.value_wholenumber_t; }
    void operator=(wholenumber_t o) { type=REXX_VALUE_wholenumber_t; value.value_wholenumber_t=o; }
};

struct RexxOption {
    const char *optionName;
    ValueDescriptor option;
};

typedef RexxObjectPtr RexxContextCommandHandler(RexxExitContext *, RexxStringObject, RexxStringObject);
typedef RexxObjectPtr RexxRedirectingCommandHandler(RexxExitContext *, RexxStringObject, RexxStringObject, RexxIORedirectorContext *);

struct RexxContextEnvironment {
    RexxContextCommandHandler *handler;
    const char *name;
};

struct RexxRedirectingEnvironment {
    RexxRedirectingCommandHandler *handler;
    const char *name;
};

struct RexxRegisteredEnvironment {
    const char *registeredName;
    const char *name;
};

struct RexxLibraryPackage {
    const char *registeredName;
    RexxPackageEntry *table;
};

#define REXX_CURRENT_INTERPRETER_VERSION 0x00050300
#define REXX_CURRENT_LANGUAGE_LEVEL 0x00000606

#endif
EOF

say "5. Legacy C++ compatibility headers -- cfront 3 profile"

cat >"$WORK/compat/string.h" <<'EOF'
#ifndef RX_CFRONT_STRING_H
#define RX_CFRONT_STRING_H
typedef unsigned int size_t;

void *memcpy(void *, const void *, size_t);
void *memmove(void *, const void *, size_t);
void *memset(void *, int, size_t);

size_t strlen(const char *);
int strcmp(const char *, const char *);
int strncmp(const char *, const char *, size_t);

char *strcpy(char *, const char *);
char *strncpy(char *, const char *, size_t);
char *strcat(char *, const char *);
char *strncat(char *, const char *, size_t);

void *memchr(const void *, int, size_t);
int memcmp(const void *, const void *, size_t);
char *strchr(const char *, int);
char *strrchr(const char *, int);

#endif
EOF

cat >"$WORK/compat/cstring" <<'EOF'
#ifndef RX_CFRONT_CSTRING
#define RX_CFRONT_CSTRING
#include <string.h>
#endif
EOF

cat >"$WORK/compat/cstddef" <<'EOF'
#ifndef RX_CFRONT_CSTDDEF
#define RX_CFRONT_CSTDDEF
typedef unsigned int size_t;
typedef long ssize_t;
typedef long ptrdiff_t;
#endif
EOF

cat >"$WORK/compat/stddef.h" <<'EOF'
#ifndef RX_CFRONT_STDDEF_H
#define RX_CFRONT_STDDEF_H
typedef unsigned int size_t;
typedef long ptrdiff_t;
#ifndef NULL
#define NULL 0
#endif
#endif
EOF

cat >"$WORK/compat/cstdint" <<'EOF'
#ifndef RX_CFRONT_CSTDINT
#define RX_CFRONT_CSTDINT
typedef unsigned long uintptr_t;
typedef long intptr_t;
typedef unsigned long uint32_t;
typedef unsigned short uint16_t;
typedef unsigned char uint8_t;
typedef long int32_t;
typedef short int16_t;
typedef signed char int8_t;
typedef unsigned long long uint64_t;
typedef long long int64_t;
#endif
EOF

cat >"$WORK/compat/stdint.h" <<'EOF'
#ifndef RX_CFRONT_STDINT_H
#define RX_CFRONT_STDINT_H
typedef signed char int8_t;
typedef unsigned char uint8_t;
typedef short int16_t;
typedef unsigned short uint16_t;
typedef long int32_t;
typedef unsigned long uint32_t;
typedef long long int64_t;
typedef unsigned long long uint64_t;
typedef long intptr_t;
typedef unsigned long uintptr_t;
#define INT32_MAX 2147483647L
#define INT32_MIN (-2147483647L - 1L)
#define UINT32_MAX 4294967295UL
#define UINTPTR_MAX 4294967295UL
#endif
EOF

cat >"$WORK/compat/stdbool.h" <<'EOF'
#ifndef RX_CFRONT_STDBOOL_H
#define RX_CFRONT_STDBOOL_H
#define bool int
#define true 1
#define false 0
#endif
EOF

cat >"$WORK/compat/stdlib.h" <<'EOF'
#ifndef RX_CFRONT_STDLIB_H
#define RX_CFRONT_STDLIB_H
typedef unsigned int size_t;
void *malloc(size_t);
void *calloc(size_t, size_t);
void *realloc(void *, size_t);
void free(void *);
int abs(int);
long labs(long);
#endif
EOF

mkdir -p "$WORK/compat/sys"
cat >"$WORK/compat/sys/types.h" <<'EOF'
#ifndef RX_CFRONT_SYS_TYPES_H
#define RX_CFRONT_SYS_TYPES_H
typedef unsigned int size_t;
typedef long ssize_t;
typedef long off_t;
typedef long time_t;
#endif
EOF

cat >"$WORK/compat/new" <<'EOF'
#ifndef RX_CFRONT_NEW
#define RX_CFRONT_NEW
typedef unsigned int size_t;
void *operator new(size_t);
void operator delete(void *);
#endif
EOF

cat >"$WORK/compat/algorithm" <<'EOF'
#ifndef RX_CFRONT_ALGORITHM
#define RX_CFRONT_ALGORITHM
template<class T> inline const T& min(const T&a,const T&b){return b<a?b:a;}
template<class T> inline const T& max(const T&a,const T&b){return a<b?b:a;}
template<class T> inline T abs(T v){return v < 0 ? -v : v;}
#endif
EOF

cat >"$WORK/compat/limits" <<'EOF'
#ifndef RX_CFRONT_LIMITS
#define RX_CFRONT_LIMITS
template<class T> class numeric_limits {
public:
 static T signaling_NaN(){return (T)0;}
 static T quiet_NaN(){return (T)0;}
 static T max(){return (T)0;}
 static T min(){return (T)0;}
};
#endif
EOF

cat >"$WORK/compat/cmath" <<'EOF'
#ifndef RX_CFRONT_CMATH
#define RX_CFRONT_CMATH
#include <math.h>
#endif
EOF

cat >"$WORK/compat/cfloat" <<'EOF'
#ifndef RX_CFRONT_CFLOAT
#define RX_CFRONT_CFLOAT
#include <float.h>
#endif
EOF

cat >"$WORK/compat/atomic" <<'EOF'
#ifndef RX_CFRONT_ATOMIC
#define RX_CFRONT_ATOMIC
template<class T> class atomic {
    T v;
public:
    atomic(T x=0):v(x){}
    T operator++(){return ++v;}
    T operator++(int){T x=v;++v;return x;}
    operator T() const{return v;}
    T load() const{return v;}
    void store(T x){v=x;}
};
#endif
EOF

cat >"$WORK/compat/vector" <<'EOF'
#ifndef RX_CFRONT_VECTOR
#define RX_CFRONT_VECTOR
#include <cstddef>
template<class T> class vector {
public:
 class iterator {
  T *p;
 public:
  iterator(T*x=0):p(x){}
  iterator&operator++(){++p;return *this;}
  int operator!=(const iterator&x)const{return p!=x.p;}
  T&operator*()const{return *p;}
 };
 iterator begin(){return iterator(0);}
 iterator end(){return iterator(0);}
 void push_back(const T&){}
 unsigned long size()const{return 0;}
 int empty()const{return size()==0;}
 T& front();
 iterator erase(iterator x){return x;}
 void clear(){}
 void swap(vector&){}
 T&operator[](unsigned long);
};
#endif
EOF

cat >"$WORK/compat/deque" <<'EOF'
#ifndef RX_CFRONT_DEQUE
#define RX_CFRONT_DEQUE
template<class T> class deque {
public:
 class iterator {
  T *p;
 public:
  iterator(T*x=0):p(x){}
  iterator&operator++(){++p;return *this;}
  int operator!=(const iterator&x)const{return p!=x.p;}
  T&operator*()const{return *p;}
 };
 deque(){}
 int empty()const{return 1;}
 void push_back(const T&){}
 T&front();
 void pop_front(){}
 iterator begin(){return iterator(0);}
 iterator end(){return iterator(0);}
 iterator erase(iterator x){return x;}
};
#endif
EOF

cat >"$WORK/compat/stdexcept" <<'EOF'
#ifndef RX_CFRONT_STDEXCEPT
#define RX_CFRONT_STDEXCEPT
class exception_ptr {
 void*p;
public:
 exception_ptr():p(0){}
 operator void*()const{return p;}
};
inline exception_ptr current_exception(){return exception_ptr();}
inline void rethrow_exception(exception_ptr){}
#endif
EOF

say "6. plain cfront fixed-width FlagSet facade (no templates/default args)"

cat >"$WORK/compat/FlagSet.hpp" <<'EOF'
#ifndef RX_CFRONT_FLAGSET_HPP
#define RX_CFRONT_FLAGSET_HPP

/*
 * cfront 3 translation facade.
 *
 * No templates, no default arguments, no nested proxy classes.
 * Runtime semantics are the same fixed-width bit sets ooRexx requires.
 */

class FlagBits
{
public:
    FlagBits(unsigned long m, int w) : bits(0), mask(m), width(w) {}

    void setOne(int p)
    {
        if (p >= 0 && p < width) bits |= ((unsigned long)1 << p);
    }

    void setValue(int p, int v)
    {
        if (p >= 0 && p < width)
        {
            if (v) bits |= ((unsigned long)1 << p);
            else bits &= ~((unsigned long)1 << p);
        }
    }

    void setAll() { bits = mask; }
    void resetAll() { bits = 0; }
    void resetOne(int p) { setValue(p, 0); }

    void flipOne(int p)
    {
        if (p >= 0 && p < width) bits ^= ((unsigned long)1 << p);
    }

    void flipAll() { bits ^= mask; }

    int testOne(int p) const
    {
        return p >= 0 && p < width &&
               (bits & ((unsigned long)1 << p)) != 0;
    }

    int anyBits() const { return bits != 0; }
    int noBits() const { return bits == 0; }
    int allBits() const { return (bits & mask) == mask; }

protected:
    unsigned long bits;
    unsigned long mask;
    int width;
};


class FlagRef
{
public:
    FlagRef(FlagBits *s, int p) : setp(s), pos(p) {}

    FlagRef &operator=(int v)
    {
        setp->setValue(pos, v);
        return *this;
    }

    operator int() const
    {
        return setp->testOne(pos);
    }

private:
    FlagBits *setp;
    int pos;
};


class FlagSet8 : public FlagBits
{
public:
    FlagSet8() : FlagBits(0xffUL, 8) {}
    FlagSet8(int a) : FlagBits(0xffUL, 8) { set(a); }
    FlagSet8(int a,int b) : FlagBits(0xffUL, 8) { set(a);set(b); }
    FlagSet8(int a,int b,int c) : FlagBits(0xffUL, 8) { set(a);set(b);set(c); }
    FlagSet8(int a,int b,int c,int d) : FlagBits(0xffUL, 8) { set(a);set(b);set(c);set(d); }
    FlagSet8(int a,int b,int c,int d,int e) : FlagBits(0xffUL, 8) { set(a);set(b);set(c);set(d);set(e); }
    FlagSet8(int a,int b,int c,int d,int e,int f) : FlagBits(0xffUL, 8) { set(a);set(b);set(c);set(d);set(e);set(f); }

    void set() { setAll(); }
    void set(int p) { setOne(p); }
    void set(int p,int v) { setValue(p,v); }
    void set(int a,int b,int c) { set(a);set(b);set(c); }
    void set(int a,int b,int c,int d) { set(a);set(b);set(c);set(d); }

    void reset() { resetAll(); }
    void reset(int p) { resetOne(p); }
    void reset(int a,int b) { reset(a);reset(b); }
    void reset(int a,int b,int c) { reset(a);reset(b);reset(c); }
    void reset(int a,int b,int c,int d) { reset(a);reset(b);reset(c);reset(d); }

    void flip() { flipAll(); }
    void flip(int p) { flipOne(p); }

    int test(int p) const { return testOne(p); }
    int operator[](int p) const { return testOne(p); }
    FlagRef operator[](int p) { return FlagRef(this,p); }

    int any() const { return anyBits(); }
    int none() const { return noBits(); }
    int all() const { return allBits(); }
};


class FlagSet16 : public FlagBits
{
public:
    FlagSet16() : FlagBits(0xffffUL, 16) {}
    FlagSet16(int a) : FlagBits(0xffffUL, 16) { set(a); }
    FlagSet16(int a,int b) : FlagBits(0xffffUL, 16) { set(a);set(b); }
    FlagSet16(int a,int b,int c) : FlagBits(0xffffUL, 16) { set(a);set(b);set(c); }
    FlagSet16(int a,int b,int c,int d) : FlagBits(0xffffUL, 16) { set(a);set(b);set(c);set(d); }
    FlagSet16(int a,int b,int c,int d,int e) : FlagBits(0xffffUL, 16) { set(a);set(b);set(c);set(d);set(e); }
    FlagSet16(int a,int b,int c,int d,int e,int f) : FlagBits(0xffffUL, 16) { set(a);set(b);set(c);set(d);set(e);set(f); }

    void set() { setAll(); }
    void set(int p) { setOne(p); }
    void set(int p,int v) { setValue(p,v); }
    void set(int a,int b,int c) { set(a);set(b);set(c); }
    void set(int a,int b,int c,int d) { set(a);set(b);set(c);set(d); }

    void reset() { resetAll(); }
    void reset(int p) { resetOne(p); }
    void reset(int a,int b) { reset(a);reset(b); }
    void reset(int a,int b,int c) { reset(a);reset(b);reset(c); }
    void reset(int a,int b,int c,int d) { reset(a);reset(b);reset(c);reset(d); }

    void flip() { flipAll(); }
    void flip(int p) { flipOne(p); }

    int test(int p) const { return testOne(p); }
    int operator[](int p) const { return testOne(p); }
    FlagRef operator[](int p) { return FlagRef(this,p); }

    int any() const { return anyBits(); }
    int none() const { return noBits(); }
    int all() const { return allBits(); }
};


class FlagSet32 : public FlagBits
{
public:
    FlagSet32() : FlagBits(0xffffffffUL, 32) {}
    FlagSet32(int a) : FlagBits(0xffffffffUL, 32) { set(a); }
    FlagSet32(int a,int b) : FlagBits(0xffffffffUL, 32) { set(a);set(b); }
    FlagSet32(int a,int b,int c) : FlagBits(0xffffffffUL, 32) { set(a);set(b);set(c); }
    FlagSet32(int a,int b,int c,int d) : FlagBits(0xffffffffUL, 32) { set(a);set(b);set(c);set(d); }
    FlagSet32(int a,int b,int c,int d,int e) : FlagBits(0xffffffffUL, 32) { set(a);set(b);set(c);set(d);set(e); }
    FlagSet32(int a,int b,int c,int d,int e,int f) : FlagBits(0xffffffffUL, 32) { set(a);set(b);set(c);set(d);set(e);set(f); }

    void set() { setAll(); }
    void set(int p) { setOne(p); }
    void set(int p,int v) { setValue(p,v); }
    void set(int a,int b,int c) { set(a);set(b);set(c); }
    void set(int a,int b,int c,int d) { set(a);set(b);set(c);set(d); }

    void reset() { resetAll(); }
    void reset(int p) { resetOne(p); }
    void reset(int a,int b) { reset(a);reset(b); }
    void reset(int a,int b,int c) { reset(a);reset(b);reset(c); }
    void reset(int a,int b,int c,int d) { reset(a);reset(b);reset(c);reset(d); }

    void flip() { flipAll(); }
    void flip(int p) { flipOne(p); }

    int test(int p) const { return testOne(p); }
    int operator[](int p) const { return testOne(p); }
    FlagRef operator[](int p) { return FlagRef(this,p); }

    int any() const { return anyBits(); }
    int none() const { return noBits(); }
    int all() const { return allBits(); }
};

#endif
EOF

say "7. Compose include path -- internal ABI and fixed-width FlagSet facade first"

LEGACY1="$CFRONT_SRC/incl-master/incl-linux32"
LEGACY2="$CFRONT_SRC/incl-master/incl-linux32/CC"

INCLUDE_FLAGS="-I$WORK/mvs -I$WORK/compat"
[ -d "$LEGACY1" ] && INCLUDE_FLAGS="$INCLUDE_FLAGS -I$LEGACY1"
[ -d "$LEGACY2" ] && INCLUDE_FLAGS="$INCLUDE_FLAGS -I$LEGACY2"
while IFS= read -r d; do
    INCLUDE_FLAGS="$INCLUDE_FLAGS -I$d"
done <"$WORK/reports/include_dirs.txt"

say "8. Prove facade wins over public API headers"

cat >"$WORK/reports/abi_probe.cpp" <<'EOF'
#include "oorexxapi.h"
int main()
{
    RXSTRING s;
    RexxOption o;
    RexxThreadContext t;
    s.strlength = 0;
    s.strptr = 0;
    o.optionName = 0;
    t.instance = 0;
    return 0;
}
EOF

set +e
eval g++ -E -P -nostdinc++ -x c++ -std=gnu++17 \
 -I"$WORK/mvs" -I"$WORK/compat" $INCLUDE_FLAGS \
 '"$WORK/reports/abi_probe.cpp"' \
 '>"$WORK/preprocessed/abi_probe.ii"' \
 '2>"$WORK/logs/abi_probe.preprocess.log"'
abi_pp_rc=$?
set -e 2>/dev/null || true

printf 'abi_preprocess_rc=%s bytes=%s\n' "$abi_pp_rc" "$(wc -c <"$WORK/preprocessed/abi_probe.ii" 2>/dev/null || echo 0)"
[ "$abi_pp_rc" -eq 0 ] || cat "$WORK/logs/abi_probe.preprocess.log"

if grep -q 'RexxRegisterFunctionDll\|PFNREXXSTART\|RexxVariablePool' "$WORK/preprocessed/abi_probe.ii" 2>/dev/null; then
    echo "FAIL: public classic API declarations leaked into internal ABI facade"
    exit 31
else
    echo "public_classic_api_leak_hits=0"
fi

say "9. Preprocess bulk core sweep against internal ABI"
: >"$WORK/reports/preprocess.tsv"

for rel in $FILES; do
    key="$(echo "$rel" | tr '/.' '__')"
    src="$OOREXX_SRC/$rel"
    own="$(dirname "$src")"

    set +e
    eval g++ -E -P -nostdinc++ -x c++ -std=gnu++17 \
      -I"$WORK/mvs" -I"$WORK/compat" -I"$own" $INCLUDE_FLAGS \
      '"$src"' \
      '>"$WORK/preprocessed/$key.ii"' \
      '2>"$WORK/logs/$key.preprocess.log"'
    rc=$?
    set -e 2>/dev/null || true

    bytes=0
    [ -s "$WORK/preprocessed/$key.ii" ] && bytes=$(wc -c <"$WORK/preprocessed/$key.ii")
    if [ "$rc" -ne 0 ]; then
        rm -f "$WORK/preprocessed/$key.ii"
        bytes=0
    fi

    printf '%-48s rc=%-3s bytes=%s\n' "$rel" "$rc" "$bytes"
    printf '%s\t%s\t%s\n' "$rel" "$rc" "$bytes" >>"$WORK/reports/preprocess.tsv"
    [ "$rc" -eq 0 ] || tail -30 "$WORK/logs/$key.preprocess.log"
done

say "10. Audit forbidden source/platform/API leakage"

: >"$WORK/reports/include_audit.txt"
for rel in $FILES; do
    key="$(echo "$rel" | tr '/.' '__')"
    src="$OOREXX_SRC/$rel"
    own="$(dirname "$src")"

    set +e
    eval g++ -E -H -nostdinc++ -x c++ -std=gnu++17 \
      -I"$WORK/mvs" -I"$WORK/compat" -I"$own" $INCLUDE_FLAGS \
      '"$src"' '>/dev/null' \
      '2>"$WORK/logs/$key.includes.log"'
    set -e 2>/dev/null || true

    cat "$WORK/logs/$key.includes.log" >>"$WORK/reports/include_audit.txt"
done

if grep -Ei '/(extensions|samples|rexxapi)/|/platform/(unix|windows)/|oodialog' \
    "$WORK/reports/include_audit.txt" >"$WORK/reports/leak.txt"; then
    echo "FAIL forbidden source/platform leakage"
    cat "$WORK/reports/leak.txt"
    exit 32
fi

echo "platform_source_leak_hits=0"

if grep -E '/usr/include/.*/stdint|/usr/include/stdint|bits/stdint|__int32_t|__inline __uint' \
    "$WORK/reports/include_audit.txt" >"$WORK/reports/host_c_integer_leak.txt"; then
    echo "host_c_integer_header_leak_hits=$(wc -l <"$WORK/reports/host_c_integer_leak.txt")"
    head -20 "$WORK/reports/host_c_integer_leak.txt"
else
    echo "host_c_integer_header_leak_hits=0"
fi

say "11. Make cfront translation shadows"

python3 - "$WORK/preprocessed" "$WORK/shadow" <<'PY'
from pathlib import Path
import sys,re

src=Path(sys.argv[1]); dst=Path(sys.argv[2])

for p in src.glob("*.ii"):
    t=p.read_text(errors="ignore")

    for word in ("override","final","noexcept"):
        t=re.sub(r'\b'+word+r'\b','',t)

    t=re.sub(r'\bnullptr\b','0',t)
    t=re.sub(r'\bstd::','',t)
    t=re.sub(r'\b__extension__\b','',t)
    t=re.sub(r'\b__signed__\b','signed',t)
    t=re.sub(r'__attribute__\s*\(\([^;{}]*?\)\)','',t)

    # cfront 3.0.3 predates built-in bool/true/false.  For translation
    # qualification use the historically equivalent integral representation.
    t=re.sub(r'\bbool\b','int',t)
    t=re.sub(r'\btrue\b','1',t)
    t=re.sub(r'\bfalse\b','0',t)

    # cfront 3 accepts the original template-era 'class' spelling rather
    # than the later 'typename' parameter spelling used by FlagSet.hpp.
    t=re.sub(r'template\s*<\s*typename\s+', 'template<class ', t)

    # The fixed-width facade preserves ooRexx's only core widths.
    t=re.sub(r'FlagSet\s*<\s*([^,<>]+)\s*,\s*8\s*>',  r'FlagSet8', t)
    t=re.sub(r'FlagSet\s*<\s*([^,<>]+)\s*,\s*16\s*>', r'FlagSet16', t)
    t=re.sub(r'FlagSet\s*<\s*([^,<>]+)\s*,\s*32\s*>', r'FlagSet32', t)
    t=re.sub(r'FlagSet\s*<\s*([^,<>]+)\s*>',            r'FlagSet16', t)

    # C++11 deleted/defaulted declarations -> ordinary declarations.
    t=re.sub(r'([^\n;{}]+\([^\n;{}]*\)[^\n;{}]*)\s*=\s*delete\s*;',r'\1;',t)
    t=re.sub(r'([^\n;{}]+\([^\n;{}]*\)[^\n;{}]*)\s*=\s*default\s*;',r'\1;',t)

    # cfront 3 predates in-class initialization of integral static const
    # members.  These are the Numerics members in the 32-bit target branch.
    numerics_names = (
        "MAX_WHOLENUMBER","MIN_WHOLENUMBER","ARGUMENT_DIGITS","SIZE_DIGITS",
        "MIN_REXXINTEGER","MAX_REXXINTEGER","REXXINTEGER_BITS",
        "MAX_EXPONENT","MIN_EXPONENT","DEFAULT_DIGITS","MAX_STRINGSIZE",
        "DIGITS64","DEFAULT_FUZZ"
    )
    for name in numerics_names:
        t=re.sub(
            r'(static\s+const\s+(?:wholenumber_t|size_t|int|long)\s+'+name+r')\s*=\s*[^;]+;',
            r'\1;',
            t
        )

    for name in ("IntegerCacheLow","IntegerCacheHigh"):
        t=re.sub(
            r'(static\s+const\s+int\s+'+name+r')\s*=\s*[^;]+;',
            r'\1;',
            t
        )

    # Preserve the exact -10..100 cache cardinality after old-style
    # static-const conversion removes compile-time initializers.
    t=t.replace(
        'RexxInteger *integercache[IntegerCacheHigh - IntegerCacheLow + 1];',
        'RexxInteger *integercache[111];'
    )

    # Defer problematic inline helper bodies while preserving layout/signatures.
    t=re.sub(
        r'class\s+AutoFree\s*\{.*?private:\s*char\s*\*value;\s*\};',
        'class AutoFree\n{\npublic:\n    AutoFree();\n    AutoFree(char *);\n    ~AutoFree();\n    AutoFree &operator=(char *);\n    operator char *() const;\n    int operator==(char *);\n    int realloc(size_t);\nprivate:\n    char *value;\n};',
        t, flags=re.S
    )

    t=re.sub(
        r'class\s+StringBuilder\s*\{.*?protected:\s*char\s*\*current;\s*\};',
        'class StringBuilder\n{\npublic:\n    StringBuilder();\n    StringBuilder(char *);\n    StringBuilder(RexxString *);\n    void init(RexxString *);\n    void append(const char *, size_t);\n    void append(const char *);\n    void append(char);\n    void append(RexxString *);\n    void pad(char, size_t);\nprotected:\n    char *current;\n};',
        t, count=1, flags=re.S
    )

    t=re.sub(
        r'class\s+StringBuilderRtL\s*\{.*?protected:\s*char\s*\*current;\s*\};',
        'class StringBuilderRtL\n{\npublic:\n    StringBuilderRtL(RexxString *);\n    void put(char);\nprotected:\n    char *current;\n};',
        t, count=1, flags=re.S
    )

    t=re.sub(
        r'class\s+WordIterator\s*\{.*?protected:\s*const\s+char\s*\*currentWord;\s*const\s+char\s*\*nextPosition;\s*size_t\s+currentWordLength;\s*size_t\s+scanLength;\s*\};',
        'class WordIterator\n{\npublic:\n    WordIterator(const char *, size_t);\n    WordIterator(RexxString *);\n    void skipBlanks(const char *&, size_t &);\n    void skipNonBlanks(const char *&, size_t &);\n    int next();\n    int skipWords(size_t);\n    void skipBlanks();\n    int compare(WordIterator &);\n    int caselessCompare(WordIterator &);\n    size_t wordLength();\n    const char *wordPointer();\n    const char *wordEndPointer();\n    void append(StringBuilder &);\n    void appendRemainder(StringBuilder &);\n    const char *scanPosition();\n    size_t length();\nprotected:\n    const char *currentWord;\n    const char *nextPosition;\n    size_t currentWordLength;\n    size_t scanLength;\n};',
        t, count=1, flags=re.S
    )

    # Old cfront accepts enum constants as in-class integral constants.
    # Preserve compile-time semantics for String option characters.
    string_char_constants = (
        "STRIP_BOTH","STRIP_LEADING","STRIP_TRAILING",
        "DATATYPE_ALPHANUMERIC","DATATYPE_BINARY","DATATYPE_INTERNAL_WHOLE",
        "DATATYPE_LOWERCASE","DATATYPE_MIXEDCASE","DATATYPE_NUMBER",
        "DATATYPE_SYMBOL","DATATYPE_VARIABLE","DATATYPE_UPPERCASE",
        "DATATYPE_WHOLE_NUMBER","DATATYPE_HEX","DATATYPE_9DIGITS",
        "DATATYPE_LOGICAL","VERIFY_MATCH","VERIFY_NOMATCH","ch_SPACE","ch_TAB"
    )
    for name in string_char_constants:
        t=re.sub(
            r'static\s+const\s+char\s+'+name+r'\s*=\s*([^;]+);',
            r'enum { '+name+r' = \1 };',
            t
        )

    # HashContents nested iterators have the same old-cfront ordering issue:
    # their inline bodies call outer HashContents methods declared later.
    t=re.sub(
        r'class\s+IndexIterator\s*\{.*?HashContents\s*\*contents;\s*RexxInternalObject\s*\*indexValue;\s*ItemLink\s+position;\s*\};',
        'class IndexIterator\n{\n    friend class HashContents;\npublic:\n    ~IndexIterator();\n    int isAvailable();\n    RexxInternalObject *value();\n    RexxInternalObject *index();\n    void replace(RexxInternalObject *);\n    void next();\nprivate:\n    IndexIterator(HashContents *, RexxInternalObject *, ItemLink);\n    HashContents *contents;\n    RexxInternalObject *indexValue;\n    ItemLink position;\n};', t, count=1, flags=re.S
    )
    t=re.sub(
        r'class\s+TableIterator\s*\{.*?HashContents\s*\*contents;\s*ItemLink\s+position;\s*ItemLink\s+nextBucket;\s*\};',
        'class TableIterator\n{\n    friend class HashContents;\npublic:\n    TableIterator();\n    ~TableIterator();\n    int isAvailable();\n    RexxInternalObject *value();\n    RexxInternalObject *index();\n    void replace(RexxInternalObject *);\n    void next();\n    void removeAndAdvance();\nprivate:\n    TableIterator(HashContents *, ItemLink, ItemLink);\n    HashContents *contents;\n    ItemLink position;\n    ItemLink nextBucket;\n};', t, count=1, flags=re.S
    )
    t=re.sub(
        r'class\s+ReverseTableIterator\s*\{.*?HashContents\s*\*contents;\s*ItemLink\s+position;\s*ItemLink\s+currentBucket;\s*\};',
        'class ReverseTableIterator\n{\n    friend class HashContents;\npublic:\n    ReverseTableIterator();\n    ~ReverseTableIterator();\n    int isAvailable();\n    RexxInternalObject *value();\n    RexxInternalObject *index();\n    void replace(RexxInternalObject *);\n    void next();\nprivate:\n    ReverseTableIterator(HashContents *, ItemLink, ItemLink);\n    HashContents *contents;\n    ItemLink position;\n    ItemLink currentBucket;\n};', t, count=1, flags=re.S
    )

    # Old-style static link sentinels: keep declarations in classes.
    t=re.sub(
        r'(static\s+const\s+(?:ItemLink|MapLink)\s+(?:NoMore|NoLink|AtEnd|AtBeginning))\s*=\s*[^;]+;',
        r'\1;', t
    )

    # HashCollection size constants must remain compile-time constants for
    # default arguments and sizing logic.  Use cfront-era enum constants.
    t=re.sub(
        r'static\s+const\s+size_t\s+MinimumBucketSize\s*=\s*17\s*;',
        r'enum { MinimumBucketSize = 17 };',
        t
    )
    t=re.sub(
        r'static\s+const\s+size_t\s+DefaultTableSize\s*=\s*17\s*;',
        r'enum { DefaultTableSize = 17 };',
        t
    )

    # MVS 3.8J / S370 memory geometry.  Pointer containers are four bytes,
    # while effective addressability is 24 bits.  Keep values needed as class
    # constant expressions in cfront-era enum form.
    t=re.sub(r'static\s+const\s+size_t\s+ObjectGrain\s*=\s*sizeof\(void \*\)\s*\*\s*2\s*;',
             'enum { ObjectGrain = 8 };', t)
    t=re.sub(r'static\s+const\s+size_t\s+MaximumObjectSize\s*=\s*SIZE_MAX\s*-\s*ObjectGrain\s*;',
             'static const size_t MaximumObjectSize;', t)

    # In-class functions are implicitly inline to cfront.  Its inline expander
    # cannot handle LiveStack::pop()'s statement after the first return; express
    # the same semantics as one return expression.
    t=re.sub(
        r'RexxInternalObject\s*\*pop\(\)\s*\{\s*if\s*\(top\s*==\s*0\)\s*\{\s*return\s+0\s*;\s*\}\s*return\s+stack\[--top\]\s*;\s*\}',
        'RexxInternalObject *pop() { return top == 0 ? 0 : stack[--top]; }',
        t, flags=re.S
    )

    # Bulk cfront-era constant normalization.  Keep Numerics members on their
    # explicit companion-definition path, but turn literal/constant-expression
    # size_t members elsewhere into enum constants so they remain usable in
    # array bounds and default arguments.
    numerics_exclude = set((
        "MAX_WHOLENUMBER","MIN_WHOLENUMBER","ARGUMENT_DIGITS","SIZE_DIGITS",
        "MIN_REXXINTEGER","MAX_REXXINTEGER","REXXINTEGER_BITS",
        "MAX_EXPONENT","MIN_EXPONENT","DEFAULT_DIGITS","MAX_STRINGSIZE",
        "DIGITS64","DEFAULT_FUZZ"
    ))
    def size_const(m):
        name=m.group(1); expr=m.group(2).strip()
        if name in numerics_exclude:
            return m.group(0)
        # Avoid pointer-valued or function-valued expressions.  These class
        # sizing constants are integer arithmetic only.
        if re.search(r'["\']|reinterpret|static_cast|sizeof\s*\(', expr):
            return m.group(0)
        return 'enum { %s = %s };' % (name, expr)

    t=re.sub(
        r'static\s+const\s+size_t\s+([A-Za-z_]\w*)\s*=\s*([^;]+);',
        size_const, t
    )

    # cfront does not reliably see members declared later in the class when
    # parsing default arguments.  Preserve the source constant while making
    # the default argument explicit for the common core sizing constants.
    default_literals = {
        "DefaultTableSize":"17",
        "MinimumBucketSize":"17",
        "DefaultOld2NewSize":"512",
        "DefaultPointerTableSize":"10",
        "DefaultArraySize":"16",
        "INITIAL_SIZE":"100",
        "EXTEND_SIZE":"25",
        "OVERFLOWSPACE":"2",
        "MINIMUM_STACK_FRAME":"10",
        "DefaultScopeListSize":"10",
        "encodingChunkLength":"72",
        "MAX_SYMBOL_LENGTH":"250",
        "defaultBufferSize":"4096",
        "DEFAULT_BUFFER_LENGTH":"256",
        "FIRST_VARIABLE_INDEX":"VARIABLE_SIGL",
        "DefaultObjectDictionarySize":"7",
        "MaxNativeArguments":"16",
        "MAX_THREAD_POOL_SIZE":"5",
        "ALLOCATION_PAD":"100",
    }
    for name,value in default_literals.items():
        t=re.sub(r'(=\s*)'+name+r'(?=\s*[,)\]])', r'\g<1>'+value, t)

    # The old translator's target model uses unsigned int as size_t when
    # pointer size is not larger than unsigned int.  Normalise source-level
    # spelling in the shadow so class operator new(size_t, extra...) is checked
    # against the same type cfront injects for the implicit allocation size.
    t=re.sub(r'\btypedef\s+unsigned\s+long\s+size_t\s*;', 'typedef unsigned int size_t;', t)


    (dst/p.name).write_text(t)
PY

python3 - "$WORK/preprocessed" "$WORK/shadow" "$WORK/reports/transform-stats.tsv" <<'PY'
from pathlib import Path
import sys,re
src=Path(sys.argv[1]); dst=Path(sys.argv[2]); out=Path(sys.argv[3])
families={
 "override_final_noexcept": re.compile(r'\b(?:override|final|noexcept)\b'),
 "flagset_template": re.compile(r'\bFlagSet\s*<'),
 "bitset_template": re.compile(r'\bBitSet\s*<'),
 "static_const_size_init": re.compile(r'static\s+const\s+size_t\s+\w+\s*='),
 "deleted_defaulted": re.compile(r'=\s*(?:delete|default)\s*;'),
 "nested_worditerator": re.compile(r'class\s+WordIterator\b'),
 "nested_hashiterator": re.compile(r'class\s+(?:IndexIterator|TableIterator|ReverseTableIterator)\b'),
}
with out.open("w") as f:
    f.write("file\tfamily\tbefore\tafter\n")
    for p in sorted(src.glob("*.ii")):
        q=dst/p.name
        if not q.exists(): continue
        a=p.read_text(errors="ignore"); b=q.read_text(errors="ignore")
        for name,rx in families.items():
            f.write(f"{p.name}\t{name}\t{len(rx.findall(a))}\t{len(rx.findall(b))}\n")
print("transform_stats",out)
PY

say "11b. Consolidated MVS24/cfront family adaptation"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
python3 "$SCRIPT_DIR/dev13_transform.py" "$WORK/shadow"
python3 "$SCRIPT_DIR/dev14_post_transform.py" "$WORK/shadow"
python3 "$SCRIPT_DIR/dev15_post_transform.py" "$WORK/shadow"
python3 "$SCRIPT_DIR/dev15_extra.py" "$WORK/shadow"

say "12. cfront core-language compatibility micro-probe"

cat >"$WORK/reports/core_language_probe.cpp" <<'EOF'
#include <new>

class Probe
{
public:
    Probe(int v) : value(v) {}
    int ok() { return value == 7; }
private:
    int value;
};

int main()
{
    bool flag = true;
    Probe *p = new Probe(7);
    char *a = new char[4];
    int rc = (flag && p->ok()) ? 0 : 9;
    delete p;
    delete[] a;
    return rc;
}
EOF

set +e
eval g++ -E -P -nostdinc++ -x c++ -std=gnu++17 \
 -I"$WORK/mvs" -I"$WORK/compat" $INCLUDE_FLAGS \
 '"$WORK/reports/core_language_probe.cpp"' \
 '>"$WORK/preprocessed/core_language_probe.ii"' \
 '2>"$WORK/logs/core_language_probe.preprocess.log"'
lang_pp_rc=$?
set -e 2>/dev/null || true

python3 - "$WORK/preprocessed/core_language_probe.ii" "$WORK/shadow/core_language_probe.ii" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1])
if not p.exists():
    raise SystemExit(0)
t=p.read_text(errors="ignore")
t=re.sub(r'\bbool\b','int',t)
t=re.sub(r'\btrue\b','1',t)
t=re.sub(r'\bfalse\b','0',t)
t=re.sub(r'\bnullptr\b','0',t)
Path(sys.argv[2]).write_text(t)
PY

lang_cf_rc=99
if [ "$lang_pp_rc" -eq 0 ] && [ -s "$WORK/shadow/core_language_probe.ii" ]; then
    set +e
    "$CFRONT" "$CFRONT_XFLAG" \
      <"$WORK/shadow/core_language_probe.ii" \
      >"$WORK/shadow/core_language_probe.c" \
      2>"$WORK/logs/core_language_probe.cfront.log"
    lang_cf_rc=$?
    set -e 2>/dev/null || true
    if [ "$lang_cf_rc" -ne 0 ]; then
        rm -f "$WORK/shadow/core_language_probe.c"
    fi
fi

printf 'core_language_preprocess_rc=%s\n' "$lang_pp_rc"
printf 'core_language_cfront_rc=%s bytes=%s\n' \
    "$lang_cf_rc" \
    "$(wc -c <"$WORK/shadow/core_language_probe.c" 2>/dev/null || echo 0)"
cat "$WORK/logs/core_language_probe.cfront.log" 2>/dev/null || true

say "13. cfront Numerics static-constant compatibility micro-probe"

cat >"$WORK/reports/numerics_probe.cpp" <<'EOF'
template<class T> inline T abs(T v) { return v < 0 ? -v : v; }
class N
{
public:
    static const long A;
    static const long B;
    static long value() { return abs(A) + B; }
};
const long N::A = -9;
const long N::B = 4;
int main() { return N::value() == 13 ? 0 : 8; }
EOF

set +e
"$CFRONT" "$CFRONT_XFLAG" \
  <"$WORK/reports/numerics_probe.cpp" \
  >"$WORK/shadow/numerics_probe.c" \
  2>"$WORK/logs/numerics_probe.cfront.log"
numerics_probe_rc=$?
set -e 2>/dev/null || true

if [ "$numerics_probe_rc" -ne 0 ]; then
    rm -f "$WORK/shadow/numerics_probe.c"
fi

printf 'numerics_probe_cfront_rc=%s bytes=%s\n' \
    "$numerics_probe_rc" \
    "$(wc -c <"$WORK/shadow/numerics_probe.c" 2>/dev/null || echo 0)"
cat "$WORK/logs/numerics_probe.cfront.log"

say "14. cfront plain-overload micro-probe"

cat >"$WORK/reports/plain_overload_probe.cpp" <<'EOF'
class P
{
public:
    P() : v(0) {}
    void set() { v = 0xff; }
    void set(int p) { v |= (1 << p); }
    void set(int p, int x) { if (x) set(p); else v &= ~(1 << p); }
    int test(int p) const { return (v & (1 << p)) != 0; }
private:
    int v;
};

int main()
{
    P p;
    p.set(2);
    p.set(3,1);
    return p.test(2) && p.test(3) ? 0 : 9;
}
EOF

set +e
"$CFRONT" "$CFRONT_XFLAG" \
  <"$WORK/reports/plain_overload_probe.cpp" \
  >"$WORK/shadow/plain_overload_probe.c" \
  2>"$WORK/logs/plain_overload_probe.cfront.log"
plain_overload_rc=$?
set -e 2>/dev/null || true

if [ "$plain_overload_rc" -ne 0 ]; then
    rm -f "$WORK/shadow/plain_overload_probe.c"
fi

printf 'plain_overload_cfront_rc=%s bytes=%s\n' \
    "$plain_overload_rc" \
    "$(wc -c <"$WORK/shadow/plain_overload_probe.c" 2>/dev/null || echo 0)"
cat "$WORK/logs/plain_overload_probe.cfront.log"

say "15. cfront fixed-width FlagSet micro-probe"

cat >"$WORK/reports/flagset_probe.cpp" <<'EOF'
#include "FlagSet.hpp"

enum ProbeFlag { PF_A = 0, PF_B = 1, PF_LAST = 31 };

int main()
{
    FlagSet8 f8;
    FlagSet16 f16;
    FlagSet32 f32;

    f8.set(PF_B);
    f16.set(PF_B);
    f32.set(PF_LAST);

    if (!f8.test(PF_B)) return 1;
    if (!f16.test(PF_B)) return 2;
    if (!f32.test(PF_LAST)) return 3;

    f8[PF_A] = 1;
    if (!f8[PF_A]) return 4;

    return 0;
}
EOF

set +e
eval g++ -E -P -nostdinc++ -x c++ -std=gnu++17 \
 -I"$WORK/mvs" -I"$WORK/compat" $INCLUDE_FLAGS \
 '"$WORK/reports/flagset_probe.cpp"' \
 '>"$WORK/preprocessed/flagset_probe.ii"' \
 '2>"$WORK/logs/flagset_probe.preprocess.log"'
flagset_pp_rc=$?
set -e 2>/dev/null || true

python3 - "$WORK/preprocessed/flagset_probe.ii" "$WORK/shadow/flagset_probe.ii" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1])
if not p.exists(): raise SystemExit(0)
t=p.read_text(errors="ignore")
t=re.sub(r'\bbool\b','int',t)
t=re.sub(r'\btrue\b','1',t)
t=re.sub(r'\bfalse\b','0',t)
Path(sys.argv[2]).write_text(t)
PY

flagset_probe_rc=99
if [ "$flagset_pp_rc" -eq 0 ] && [ -s "$WORK/shadow/flagset_probe.ii" ]; then
    set +e
    "$CFRONT" "$CFRONT_XFLAG" \
      <"$WORK/shadow/flagset_probe.ii" \
      >"$WORK/shadow/flagset_probe.c" \
      2>"$WORK/logs/flagset_probe.cfront.log"
    flagset_probe_rc=$?
    set -e 2>/dev/null || true
fi

if [ "$flagset_probe_rc" -ne 0 ]; then
    rm -f "$WORK/shadow/flagset_probe.c"
fi

printf 'flagset_probe_preprocess_rc=%s\n' "$flagset_pp_rc"
printf 'flagset_probe_cfront_rc=%s bytes=%s\n' \
    "$flagset_probe_rc" \
    "$(wc -c <"$WORK/shadow/flagset_probe.c" 2>/dev/null || echo 0)"
cat "$WORK/logs/flagset_probe.preprocess.log" 2>/dev/null || true
cat "$WORK/logs/flagset_probe.cfront.log" 2>/dev/null || true

say "16. cfront deferred-inline helper micro-probe"

cat >"$WORK/reports/deferred_inline_probe.cpp" <<'EOF'
class Outer;

class Helper
{
public:
    Helper();
    Helper(Outer *);
    int get() const;
private:
    Outer *owner;
};

class Outer
{
public:
    Outer() : value(7) {}
    int read() const { return value; }
private:
    int value;
};

Helper::Helper() : owner(0) {}
Helper::Helper(Outer *o) : owner(o) {}
int Helper::get() const { return owner ? owner->read() : 0; }

int main()
{
    Outer o;
    Helper h(&o);
    return h.get() == 7 ? 0 : 8;
}
EOF

set +e
"$CFRONT" "$CFRONT_XFLAG" \
  <"$WORK/reports/deferred_inline_probe.cpp" \
  >"$WORK/shadow/deferred_inline_probe.c" \
  2>"$WORK/logs/deferred_inline_probe.cfront.log"
deferred_inline_rc=$?
set -e 2>/dev/null || true

if [ "$deferred_inline_rc" -ne 0 ]; then
    rm -f "$WORK/shadow/deferred_inline_probe.c"
fi

printf 'deferred_inline_cfront_rc=%s bytes=%s\n' \
    "$deferred_inline_rc" \
    "$(wc -c <"$WORK/shadow/deferred_inline_probe.c" 2>/dev/null || echo 0)"
cat "$WORK/logs/deferred_inline_probe.cfront.log"

say "17. cfront nested-helper/char-constant micro-probe"

cat >"$WORK/reports/string_nested_probe.cpp" <<'EOF'
class S
{
public:
    enum { A = 'A' };
    enum { B = 'B' };

    class I
    {
    public:
        I(const char *, unsigned long);
        int next();
        unsigned long length();
    protected:
        const char *p;
        unsigned long n;
    };

    static int choose(int c)
    {
        switch (c)
        {
            case A: return 1;
            case B: return 2;
        }
        return 0;
    }
};

int main()
{
    return S::choose('B') == 2 ? 0 : 9;
}
EOF

set +e
"$CFRONT" "$CFRONT_XFLAG" \
  <"$WORK/reports/string_nested_probe.cpp" \
  >"$WORK/shadow/string_nested_probe.c" \
  2>"$WORK/logs/string_nested_probe.cfront.log"
string_nested_rc=$?
set -e 2>/dev/null || true

if [ "$string_nested_rc" -ne 0 ]; then
    rm -f "$WORK/shadow/string_nested_probe.c"
fi

printf 'string_nested_cfront_rc=%s bytes=%s\n' \
    "$string_nested_rc" \
    "$(wc -c <"$WORK/shadow/string_nested_probe.c" 2>/dev/null || echo 0)"
cat "$WORK/logs/string_nested_probe.cfront.log"

say "18. cfront generic memcpy/hash-iterator micro-probe"

cat >"$WORK/reports/hash_iterator_probe.cpp" <<'EOF'
#include <string.h>

class H
{
public:
    typedef unsigned long Link;

    class I
    {
        friend class H;
    public:
        I();
        int available();
        int value();
        void next();
    private:
        I(H *, Link);
        H *owner;
        Link position;
    };

    int entryValue(Link p) { return (int)p; }
    void iterate(Link &p) { ++p; }
};

int copyProbe(void *d, const void *s, unsigned long n)
{
    memcpy(d, s, n);
    return 0;
}

int main()
{
    return 0;
}
EOF

set +e
eval g++ -E -P -nostdinc++ -x c++ -std=gnu++17 \
 -I"$WORK/mvs" -I"$WORK/compat" $INCLUDE_FLAGS \
 '"$WORK/reports/hash_iterator_probe.cpp"' \
 '>"$WORK/preprocessed/hash_iterator_probe.ii"' \
 '2>"$WORK/logs/hash_iterator_probe.preprocess.log"'
hash_iter_pp_rc=$?
set -e 2>/dev/null || true

hash_iter_cf_rc=99
if [ "$hash_iter_pp_rc" -eq 0 ]; then
    set +e
    "$CFRONT" "$CFRONT_XFLAG" \
      <"$WORK/preprocessed/hash_iterator_probe.ii" \
      >"$WORK/shadow/hash_iterator_probe.c" \
      2>"$WORK/logs/hash_iterator_probe.cfront.log"
    hash_iter_cf_rc=$?
    set -e 2>/dev/null || true
fi

if [ "$hash_iter_cf_rc" -ne 0 ]; then
    rm -f "$WORK/shadow/hash_iterator_probe.c"
fi

printf 'hash_iterator_preprocess_rc=%s\n' "$hash_iter_pp_rc"
printf 'hash_iterator_cfront_rc=%s bytes=%s\n' \
    "$hash_iter_cf_rc" \
    "$(wc -c <"$WORK/shadow/hash_iterator_probe.c" 2>/dev/null || echo 0)"
cat "$WORK/logs/hash_iterator_probe.preprocess.log" 2>/dev/null || true
cat "$WORK/logs/hash_iterator_probe.cfront.log" 2>/dev/null || true

say "19. cfront/MVS24 scalar-model micro-probe"

cat >"$WORK/reports/mvs24_scalar_probe.cpp" <<'EOF'
#include <stddef.h>
#include <stdint.h>

class P24
{
public:
    P24() : word(0) {}
    uintptr_t word;
};

int main()
{
    size_t s = (size_t)1;
    uintptr_t u = (uintptr_t)0x00ffffffUL;
    return (s == 1 && u == 0x00ffffffUL) ? 0 : 9;
}
EOF

set +e
eval g++ -E -P -nostdinc++ -x c++ -std=gnu++17 \
 -I"$WORK/mvs" -I"$WORK/compat" $INCLUDE_FLAGS \
 '"$WORK/reports/mvs24_scalar_probe.cpp"' \
 '>"$WORK/preprocessed/mvs24_scalar_probe.ii"' \
 '2>"$WORK/logs/mvs24_scalar_probe.preprocess.log"'
mvs24_scalar_pp_rc=$?
set -e 2>/dev/null || true

mvs24_scalar_cf_rc=99
if [ "$mvs24_scalar_pp_rc" -eq 0 ]; then
    set +e
    "$CFRONT" "$CFRONT_XFLAG" <"$WORK/preprocessed/mvs24_scalar_probe.ii" \
      >"$WORK/shadow/mvs24_scalar_probe.c" \
      2>"$WORK/logs/mvs24_scalar_probe.cfront.log"
    mvs24_scalar_cf_rc=$?
    set -e 2>/dev/null || true
fi
if [ "$mvs24_scalar_cf_rc" -ne 0 ]; then rm -f "$WORK/shadow/mvs24_scalar_probe.c"; fi
printf 'mvs24_scalar_preprocess_rc=%s\n' "$mvs24_scalar_pp_rc"
printf 'mvs24_scalar_cfront_rc=%s bytes=%s\n' "$mvs24_scalar_cf_rc" \
  "$(wc -c <"$WORK/shadow/mvs24_scalar_probe.c" 2>/dev/null || echo 0)"
cat "$WORK/logs/mvs24_scalar_probe.cfront.log" 2>/dev/null || true

say "20. cfront class placement-new micro-probe"

cat >"$WORK/reports/placement_new_probe.cpp" <<'EOF'
typedef unsigned int size_t;

void *raw_alloc(size_t);

class Variable
{
public:
    void *operator new(size_t size, size_t capacity);
    Variable(size_t a, size_t b) : first(a), second(b) {}
    size_t first;
    size_t second;
};

void *Variable::operator new(size_t size, size_t capacity)
{
    return raw_alloc(size + capacity);
}

int main()
{
    size_t totalSize = 32;
    Variable *v = new (totalSize) Variable(7, totalSize);
    return v == 0;
}
EOF

set +e
"$CFRONT" "$CFRONT_XFLAG" \
  <"$WORK/reports/placement_new_probe.cpp" \
  >"$WORK/shadow/placement_new_probe.c" \
  2>"$WORK/logs/placement_new_probe.cfront.log"
placement_new_rc=$?
set -e 2>/dev/null || true

if [ "$placement_new_rc" -ne 0 ]; then
    rm -f "$WORK/shadow/placement_new_probe.c"
fi

printf 'placement_new_cfront_rc=%s bytes=%s\n' \
    "$placement_new_rc" \
    "$(wc -c <"$WORK/shadow/placement_new_probe.c" 2>/dev/null || echo 0)"
cat "$WORK/logs/placement_new_probe.cfront.log"

say "21. Generate old-style Numerics constant definition companion"

cat >"$WORK/reports/NumericsCfrontConstants.cpp" <<'EOF'
#include "RexxCore.h"
#include "Numerics.hpp"

/*
 * Translation companion for cfront 3.
 *
 * The authoritative Numerics.hpp initializers are removed only in the
 * preprocessed translation shadow.  Their 32-bit target values are defined
 * here in the pre-C++11 out-of-class form.
 */
const wholenumber_t Numerics::MAX_WHOLENUMBER = 999999999;
const wholenumber_t Numerics::MIN_WHOLENUMBER = -999999999;
const wholenumber_t Numerics::ARGUMENT_DIGITS = 9;
const wholenumber_t Numerics::SIZE_DIGITS = 10;
const wholenumber_t Numerics::MIN_REXXINTEGER = Numerics::MIN_WHOLENUMBER;
const wholenumber_t Numerics::MAX_REXXINTEGER = Numerics::MAX_WHOLENUMBER;
const wholenumber_t Numerics::REXXINTEGER_BITS = 32;
const wholenumber_t Numerics::MAX_EXPONENT = 999999999;
const wholenumber_t Numerics::MIN_EXPONENT = -999999999;
const wholenumber_t Numerics::DEFAULT_DIGITS = 9;
const size_t Numerics::MAX_STRINGSIZE = Numerics::MAX_WHOLENUMBER;
const wholenumber_t Numerics::DIGITS64 = 20;
const wholenumber_t Numerics::DEFAULT_FUZZ = 0;

#include "IntegerClass.hpp"
const int RexxIntegerClass::IntegerCacheLow = -10;
const int RexxIntegerClass::IntegerCacheHigh = 100;

#include "Memory.hpp"
const size_t Memory::MaximumObjectSize = 4294967287U;

#include "HashContents.hpp"
#include "ListContents.hpp"
#include "MapBucket.hpp"
#include "PointerBucket.hpp"

const HashContents::ItemLink HashContents::NoMore = SIZE_MAX;
const HashContents::ItemLink HashContents::NoLink = SIZE_MAX;

const ListContents::ItemLink ListContents::NoMore = SIZE_MAX;
const ListContents::ItemLink ListContents::NoLink = SIZE_MAX;
const ListContents::ItemLink ListContents::AtEnd = SIZE_MAX;
const ListContents::ItemLink ListContents::AtBeginning = SIZE_MAX - 1;

const MapBucket::MapLink MapBucket::NoMore = 0;
const MapBucket::MapLink MapBucket::NoLink = ~((MapBucket::MapLink)0);

const PointerBucket::MapLink PointerBucket::NoMore = 0;
const PointerBucket::MapLink PointerBucket::NoLink = ~((PointerBucket::MapLink)0);
EOF

set +e
eval g++ -E -P -nostdinc++ -x c++ -std=gnu++17 \
 -I"$WORK/mvs" -I"$WORK/compat" $INCLUDE_FLAGS \
 '"$WORK/reports/NumericsCfrontConstants.cpp"' \
 '>"$WORK/preprocessed/NumericsCfrontConstants.ii"' \
 '2>"$WORK/logs/NumericsCfrontConstants.preprocess.log"'
numerics_pp_rc=$?
set -e 2>/dev/null || true

if [ "$numerics_pp_rc" -eq 0 ]; then
python3 - "$WORK/preprocessed/NumericsCfrontConstants.ii" "$WORK/shadow/NumericsCfrontConstants.ii" <<'PY'
from pathlib import Path
import sys,re
t=Path(sys.argv[1]).read_text(errors="ignore")
for word in ("override","final","noexcept"):
    t=re.sub(r'\b'+word+r'\b','',t)
t=re.sub(r'\bnullptr\b','0',t)
t=re.sub(r'\bstd::','',t)
t=re.sub(r'\bbool\b','int',t)
t=re.sub(r'\btrue\b','1',t)
t=re.sub(r'\bfalse\b','0',t)
t=re.sub(r'template\s*<\s*typename\s+', 'template<class ', t)
t=re.sub(r'FlagSet\s*<\s*([^,<>]+)\s*,\s*8\s*>',  r'FlagSet8', t)
t=re.sub(r'FlagSet\s*<\s*([^,<>]+)\s*,\s*16\s*>', r'FlagSet16', t)
t=re.sub(r'FlagSet\s*<\s*([^,<>]+)\s*,\s*32\s*>', r'FlagSet32', t)
t=re.sub(r'FlagSet\s*<\s*([^,<>]+)\s*>',            r'FlagSet16', t)
t=re.sub(r'\b__extension__\b','',t)
t=re.sub(r'\b__signed__\b','signed',t)
t=re.sub(r'__attribute__\s*\(\([^;{}]*?\)\)','',t)
names=(
 "MAX_WHOLENUMBER","MIN_WHOLENUMBER","ARGUMENT_DIGITS","SIZE_DIGITS",
 "MIN_REXXINTEGER","MAX_REXXINTEGER","REXXINTEGER_BITS",
 "MAX_EXPONENT","MIN_EXPONENT","DEFAULT_DIGITS","MAX_STRINGSIZE",
 "DIGITS64","DEFAULT_FUZZ"
)
# Only strip in-class forms; out-of-class Numerics:: definitions remain.
for name in names:
    t=re.sub(
      r'(static\s+const\s+(?:wholenumber_t|size_t|int|long)\s+'+name+r')\s*=\s*[^;]+;',
      r'\1;', t)

for name in ("IntegerCacheLow","IntegerCacheHigh"):
    t=re.sub(
      r'(static\s+const\s+int\s+'+name+r')\s*=\s*[^;]+;',
      r'\1;', t)

t=t.replace(
    'RexxInteger *integercache[IntegerCacheHigh - IntegerCacheLow + 1];',
    'RexxInteger *integercache[111];'
)
t=re.sub(
    r'class\s+AutoFree\s*\{.*?private:\s*char\s*\*value;\s*\};',
    'class AutoFree\n{\npublic:\n    AutoFree();\n    AutoFree(char *);\n    ~AutoFree();\n    AutoFree &operator=(char *);\n    operator char *() const;\n    int operator==(char *);\n    int realloc(size_t);\nprivate:\n    char *value;\n};',
    t, flags=re.S
)
t=re.sub(
    r'class\s+StringBuilder\s*\{.*?protected:\s*char\s*\*current;\s*\};',
    'class StringBuilder\n{\npublic:\n    StringBuilder();\n    StringBuilder(char *);\n    StringBuilder(RexxString *);\n    void init(RexxString *);\n    void append(const char *, size_t);\n    void append(const char *);\n    void append(char);\n    void append(RexxString *);\n    void pad(char, size_t);\nprotected:\n    char *current;\n};',
    t, count=1, flags=re.S
)
t=re.sub(
    r'class\s+StringBuilderRtL\s*\{.*?protected:\s*char\s*\*current;\s*\};',
    'class StringBuilderRtL\n{\npublic:\n    StringBuilderRtL(RexxString *);\n    void put(char);\nprotected:\n    char *current;\n};',
    t, count=1, flags=re.S
)

t=re.sub(
    r'class\s+WordIterator\s*\{.*?protected:\s*const\s+char\s*\*currentWord;\s*const\s+char\s*\*nextPosition;\s*size_t\s+currentWordLength;\s*size_t\s+scanLength;\s*\};',
    'class WordIterator\n{\npublic:\n    WordIterator(const char *, size_t);\n    WordIterator(RexxString *);\n    void skipBlanks(const char *&, size_t &);\n    void skipNonBlanks(const char *&, size_t &);\n    int next();\n    int skipWords(size_t);\n    void skipBlanks();\n    int compare(WordIterator &);\n    int caselessCompare(WordIterator &);\n    size_t wordLength();\n    const char *wordPointer();\n    const char *wordEndPointer();\n    void append(StringBuilder &);\n    void appendRemainder(StringBuilder &);\n    const char *scanPosition();\n    size_t length();\nprotected:\n    const char *currentWord;\n    const char *nextPosition;\n    size_t currentWordLength;\n    size_t scanLength;\n};',
    t, count=1, flags=re.S
)
string_char_constants = (
    "STRIP_BOTH","STRIP_LEADING","STRIP_TRAILING",
    "DATATYPE_ALPHANUMERIC","DATATYPE_BINARY","DATATYPE_INTERNAL_WHOLE",
    "DATATYPE_LOWERCASE","DATATYPE_MIXEDCASE","DATATYPE_NUMBER",
    "DATATYPE_SYMBOL","DATATYPE_VARIABLE","DATATYPE_UPPERCASE",
    "DATATYPE_WHOLE_NUMBER","DATATYPE_HEX","DATATYPE_9DIGITS",
    "DATATYPE_LOGICAL","VERIFY_MATCH","VERIFY_NOMATCH","ch_SPACE","ch_TAB"
)
for name in string_char_constants:
    t=re.sub(
        r'static\s+const\s+char\s+'+name+r'\s*=\s*([^;]+);',
        r'enum { '+name+r' = \1 };',
        t
    )

t=re.sub(
    r'class\s+IndexIterator\s*\{.*?HashContents\s*\*contents;\s*RexxInternalObject\s*\*indexValue;\s*ItemLink\s+position;\s*\};',
    'class IndexIterator\n{\n    friend class HashContents;\npublic:\n    ~IndexIterator();\n    int isAvailable();\n    RexxInternalObject *value();\n    RexxInternalObject *index();\n    void replace(RexxInternalObject *);\n    void next();\nprivate:\n    IndexIterator(HashContents *, RexxInternalObject *, ItemLink);\n    HashContents *contents;\n    RexxInternalObject *indexValue;\n    ItemLink position;\n};', t, count=1, flags=re.S
)
t=re.sub(
    r'class\s+TableIterator\s*\{.*?HashContents\s*\*contents;\s*ItemLink\s+position;\s*ItemLink\s+nextBucket;\s*\};',
    'class TableIterator\n{\n    friend class HashContents;\npublic:\n    TableIterator();\n    ~TableIterator();\n    int isAvailable();\n    RexxInternalObject *value();\n    RexxInternalObject *index();\n    void replace(RexxInternalObject *);\n    void next();\n    void removeAndAdvance();\nprivate:\n    TableIterator(HashContents *, ItemLink, ItemLink);\n    HashContents *contents;\n    ItemLink position;\n    ItemLink nextBucket;\n};', t, count=1, flags=re.S
)
t=re.sub(
    r'class\s+ReverseTableIterator\s*\{.*?HashContents\s*\*contents;\s*ItemLink\s+position;\s*ItemLink\s+currentBucket;\s*\};',
    'class ReverseTableIterator\n{\n    friend class HashContents;\npublic:\n    ReverseTableIterator();\n    ~ReverseTableIterator();\n    int isAvailable();\n    RexxInternalObject *value();\n    RexxInternalObject *index();\n    void replace(RexxInternalObject *);\n    void next();\nprivate:\n    ReverseTableIterator(HashContents *, ItemLink, ItemLink);\n    HashContents *contents;\n    ItemLink position;\n    ItemLink currentBucket;\n};', t, count=1, flags=re.S
)
t=re.sub(
    r'(static\s+const\s+(?:ItemLink|MapLink)\s+(?:NoMore|NoLink|AtEnd|AtBeginning))\s*=\s*[^;]+;',
    r'\1;', t
)

t=re.sub(
    r'static\s+const\s+size_t\s+MinimumBucketSize\s*=\s*17\s*;',
    r'enum { MinimumBucketSize = 17 };',
    t
)
t=re.sub(
    r'static\s+const\s+size_t\s+DefaultTableSize\s*=\s*17\s*;',
    r'enum { DefaultTableSize = 17 };',
    t
)
t=re.sub(
    r'new\s*\(\s*totalSize\s*\)\s*(IdentityHashContents|EqualityHashContents|MultiValueContents|StringHashContents)',
    r'new ((size_t)totalSize) \1',
    t
)
Path(sys.argv[2]).write_text(t)
PY

    set +e
    "$CFRONT" "$CFRONT_XFLAG" \
      <"$WORK/shadow/NumericsCfrontConstants.ii" \
      >"$WORK/shadow/NumericsCfrontConstants.c" \
      2>"$WORK/logs/NumericsCfrontConstants.cfront.log"
    numerics_cf_rc=$?
    set -e 2>/dev/null || true
else
    numerics_cf_rc=99
fi

if [ "$numerics_cf_rc" -ne 0 ]; then
    rm -f "$WORK/shadow/NumericsCfrontConstants.c"
fi

printf 'numerics_companion_preprocess_rc=%s\n' "$numerics_pp_rc"
printf 'numerics_companion_cfront_rc=%s bytes=%s\n' \
    "$numerics_cf_rc" \
    "$(wc -c <"$WORK/shadow/NumericsCfrontConstants.c" 2>/dev/null || echo 0)"
cat "$WORK/logs/NumericsCfrontConstants.preprocess.log" 2>/dev/null || true
cat "$WORK/logs/NumericsCfrontConstants.cfront.log" 2>/dev/null || true

say "22. cfront internal-ABI micro-probe"

set +e
"$CFRONT" "$CFRONT_XFLAG" \
  <"$WORK/shadow/abi_probe.ii" \
  >"$WORK/shadow/abi_probe.c" \
  2>"$WORK/logs/abi_probe.cfront.log"
abi_cf_rc=$?
set -e 2>/dev/null || true

if [ "$abi_cf_rc" -ne 0 ]; then
    rm -f "$WORK/shadow/abi_probe.c"
fi

printf 'abi_cfront_rc=%s bytes=%s\n' \
    "$abi_cf_rc" \
    "$(wc -c <"$WORK/shadow/abi_probe.c" 2>/dev/null || echo 0)"

cat "$WORK/logs/abi_probe.cfront.log"

say "23. cfront bulk core probes"

: >"$WORK/reports/cfront.tsv"

for rel in $FILES; do
    key="$(echo "$rel" | tr '/.' '__')"
    in="$WORK/shadow/$key.ii"
    out="$WORK/shadow/$key.c"
    log="$WORK/logs/$key.cfront.log"

    if [ ! -s "$in" ]; then
        printf 'SKIP %-48s no unit\n' "$rel"
        printf '%s\tSKIP\t0\n' "$rel" >>"$WORK/reports/cfront.tsv"
        continue
    fi

    set +e
    "$CFRONT" "$CFRONT_XFLAG" <"$in" >"$out" 2>"$log"
    rc=$?
    set -e 2>/dev/null || true

    bytes=0
    [ -f "$out" ] && bytes=$(wc -c <"$out")

    if [ "$rc" -ne 0 ]; then
        rm -f "$out"
        bytes=0
    fi

    printf 'CFRONT %-45s rc=%-3s bytes=%s\n' "$rel" "$rc" "$bytes"
    printf '%s\t%s\t%s\n' "$rel" "$rc" "$bytes" >>"$WORK/reports/cfront.tsv"

    [ "$rc" -eq 0 ] || head -40 "$log"
done

say "24. First real blocker report"

python3 - "$WORK/logs" "$WORK/reports/first_errors.txt" <<'PY'
from pathlib import Path
import sys

logs=Path(sys.argv[1])
out=Path(sys.argv[2])

rows=[]
for p in sorted(logs.glob("*.cfront.log")):
    errors=[
        x for x in p.read_text(errors="ignore").splitlines()
        if "error:" in x.lower() or "internal" in x.lower()
    ]
    rows.append(p.name)
    rows.extend("  "+x for x in errors[:15])
    rows.append("")

out.write_text("\n".join(rows))
print(out.read_text())
PY

say "25. MVS SJLJ unwind runtime qualification"

unwind_cf_rc=99
unwind_cc370_rc=99
if [ -f "$SCRIPT_DIR/MvsUnwind.cpp" ]; then
    set +e
    "$CFRONT" "$CFRONT_XFLAG" <"$SCRIPT_DIR/MvsUnwind.cpp" \
      >"$WORK/shadow/MvsUnwind.c" 2>"$WORK/logs/MvsUnwind.cfront.log"
    unwind_cf_rc=$?
    set -e 2>/dev/null || true
    if [ "$unwind_cf_rc" -eq 0 ] && [ -s "$WORK/shadow/MvsUnwind.c" ] && [ -x "$XGCC" ]; then
        set +e
        "$XGCC" -B"$CC370_SRC/build/gcc/" -S "$WORK/shadow/MvsUnwind.c" \
          -o "$WORK/shadow/MvsUnwind.370.s" >"$WORK/logs/MvsUnwind.cc370.log" 2>&1
        unwind_cc370_rc=$?
        set -e 2>/dev/null || true
    fi
fi
printf 'mvs_unwind_cfront_rc=%s c_bytes=%s\n' "$unwind_cf_rc" "$(wc -c <"$WORK/shadow/MvsUnwind.c" 2>/dev/null || echo 0)"
printf 'mvs_unwind_cc370_rc=%s asm_bytes=%s\n' "$unwind_cc370_rc" "$(wc -c <"$WORK/shadow/MvsUnwind.370.s" 2>/dev/null || echo 0)"
cat "$WORK/logs/MvsUnwind.cfront.log" 2>/dev/null || true
cat "$WORK/logs/MvsUnwind.cc370.log" 2>/dev/null || true

say "26. cc370 S/370 generation for successful REAL ooRexx translations"

cc370_pass=0
cc370_fail=0

if [ -x "$XGCC" ]; then
    if [ -s "$WORK/shadow/NumericsCfrontConstants.c" ]; then
        set +e
        "$XGCC" -B"$CC370_SRC/build/gcc/" -S             "$WORK/shadow/NumericsCfrontConstants.c"             -o "$WORK/shadow/NumericsCfrontConstants.370.s"             >"$WORK/logs/NumericsCfrontConstants.cc370.log" 2>&1
        nrc=$?
        set -e 2>/dev/null || true
        nbytes=0
        [ -s "$WORK/shadow/NumericsCfrontConstants.370.s" ] && nbytes=$(wc -c <"$WORK/shadow/NumericsCfrontConstants.370.s")
        printf 'CC370 %-46s rc=%-3s asm_bytes=%s\n' "NumericsCfrontConstants.cpp" "$nrc" "$nbytes"
        if [ "$nrc" -eq 0 ] && [ "$nbytes" -gt 0 ]; then
            cc370_pass=$((cc370_pass + 1))
        else
            cc370_fail=$((cc370_fail + 1))
            rm -f "$WORK/shadow/NumericsCfrontConstants.370.s"
            head -35 "$WORK/logs/NumericsCfrontConstants.cc370.log"
        fi
    fi

    for rel in $FILES; do
        key="$(echo "$rel" | tr '/.' '__')"
        cfile="$WORK/shadow/$key.c"
        asm="$WORK/shadow/$key.370.s"
        log="$WORK/logs/$key.cc370.log"

        [ -s "$cfile" ] || continue

        set +e
        "$XGCC" -B"$CC370_SRC/build/gcc/" -S "$cfile" -o "$asm" >"$log" 2>&1
        rc=$?
        set -e 2>/dev/null || true

        bytes=0
        [ -s "$asm" ] && bytes=$(wc -c <"$asm")

        printf 'CC370 %-46s rc=%-3s asm_bytes=%s\n' "$rel" "$rc" "$bytes"

        if [ "$rc" -eq 0 ] && [ "$bytes" -gt 0 ]; then
            cc370_pass=$((cc370_pass + 1))
        else
            cc370_fail=$((cc370_fail + 1))
            rm -f "$asm"
            head -35 "$log"
        fi
    done
else
    echo "cc370_xgcc=NOT_FOUND ($XGCC)"
fi

say "27. Verdict"

pre="$(awk -F'\t' '$2==0 {n++} END{print n+0}' "$WORK/reports/preprocess.tsv")"
cf="$(awk -F'\t' '$2==0 {n++} END{print n+0}' "$WORK/reports/cfront.tsv")"

printf 'internal_abi_preprocess_rc=%s\n' "$abi_pp_rc"
printf 'internal_abi_cfront_rc=%s\n' "$abi_cf_rc"
printf 'core_language_preprocess_rc=%s\n' "$lang_pp_rc"
printf 'core_language_cfront_rc=%s\n' "$lang_cf_rc"
printf 'numerics_probe_cfront_rc=%s\n' "$numerics_probe_rc"
printf 'plain_overload_cfront_rc=%s\n' "$plain_overload_rc"
printf 'flagset_probe_preprocess_rc=%s\n' "$flagset_pp_rc"
printf 'flagset_probe_cfront_rc=%s\n' "$flagset_probe_rc"
printf 'deferred_inline_cfront_rc=%s\n' "$deferred_inline_rc"
printf 'string_nested_cfront_rc=%s\n' "$string_nested_rc"
printf 'hash_iterator_preprocess_rc=%s\n' "$hash_iter_pp_rc"
printf 'hash_iterator_cfront_rc=%s\n' "$hash_iter_cf_rc"
printf 'mvs24_effective_address_bits=24\n'
printf 'mvs24_address_mask=0x00ffffff\n'
printf 'sweep_mode=%s\n' "$SWEEP_MODE"
printf 'mvs24_scalar_preprocess_rc=%s\n' "$mvs24_scalar_pp_rc"
printf 'mvs24_scalar_cfront_rc=%s\n' "$mvs24_scalar_cf_rc"
printf 'placement_new_cfront_rc=%s\n' "$placement_new_rc"
printf 'mvs_unwind_cfront_rc=%s\n' "$unwind_cf_rc"
printf 'mvs_unwind_cc370_rc=%s\n' "$unwind_cc370_rc"
printf 'numerics_companion_preprocess_rc=%s\n' "$numerics_pp_rc"
printf 'numerics_companion_cfront_rc=%s\n' "$numerics_cf_rc"
total_files="$(printf '%s\n' $FILES | sed '/^$/d' | wc -l)"
printf 'core_preprocessed=%s/%s\n' "$pre" "$total_files"
printf 'core_cfront=%s/%s\n' "$cf" "$total_files"
printf 'real_oorexx_cc370_pass=%s\n' "$cc370_pass"
printf 'real_oorexx_cc370_fail=%s\n' "$cc370_fail"

echo "public_classic_api=DEFERRED"
echo "unix_windows_platform=EXCLUDED"
echo "extensions_samples_rexxapi=EXCLUDED"
echo
echo "Bulk pass: whole-core family census, cfront/S370 size_t normalization, generalized integral constants, nested-helper seams, MVS24 audit, broad cfront and cc370 sweep."
echo "It does not claim the public ooRexx API has been ported."
echo "workdir=$WORK"
