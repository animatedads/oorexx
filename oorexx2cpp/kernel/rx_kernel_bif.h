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
}
