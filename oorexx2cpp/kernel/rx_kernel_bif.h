// Interface to the compiled-in ooRexx kernel: the REAL builtin_function_* handlers from BuiltinFunctions.cpp.
// Only this header is visible to generated programs; the kernel headers live in rx_kernel_bif.cpp (they cannot share a TU).
#pragma once
#include <string>
#include <vector>
namespace rxkernel {
bool handles(const std::string &upperName);   // true for the BIFs that need no activation
// present[i] == false: argument i was omitted (the kernel receives NULL). Returns false on a Rexx error and fills code ("40.5") and text.
bool call(const std::string &upperName, const std::vector<std::string> &args, const std::vector<bool> &present,
          std::string &rxResult, std::string &rxCode, std::string &rxText);

// Real kernel objects. A handle is an opaque, GC-protected reference (global reference) to an interpreter object.
void *findClass(const std::string &name);       // retained handle to the class (.ARRAY, .DIRECTORY, ...), or nullptr
void *retain(void *handle);                      // another reference to the same object
void release(void *handle);
struct Arg { void *obj = nullptr; std::string bytes; bool omitted = false; };          // obj == nullptr: a string argument
struct Result { int kind = 0; std::string bytes; void *obj = nullptr; };   // kind 0 none, 1 string, 2 object (retained handle)
bool send(void *target, const std::string &selector, const std::vector<Arg> &args, Result &out,
          std::string &rxCode, std::string &rxText);
void *nil();                                       // .NIL
bool sameObject(void *a, void *b);
}
