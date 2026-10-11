# Kernel spike: compile the real ooRexx source in

Result (ooRexx 5.3.0 source, gcc, 2 cores): `rexx` + `rexxapi` build as static libraries from the unmodified source tree
(only `SHARED` -> `STATIC` in a copy of CMakeLists.txt). `direct_call.cpp` links them into a 2.2 MB program, starts the kernel
with `RexxCreateInterpreter`, enters it with `ApiContext`, and calls `RexxString::substr(n, length, pad)` directly:

    substr('hello',2,,'*')   -> ello      (omitted length = OREF_NULL; the kernel applies the default)
    substr('hello',2,6,'*')  -> ello**

Findings
- The kernel restores a saved image (`rexx.img`) at start-up (BASEIMAGE; searched in the library location, cwd, PATH).
  Missing image = SIGILL in `Interpreter::logicError("cannot locate startup image")`. Build target `rexx_img` makes it.
  Later: embed the image in the output binary so a compiled program is a single file.
- BIF handlers in `BuiltinFunctions.cpp` are thin: argument macros then `return string->substr(n, length, pad);`.
  `bif2signature.rex` (external/bif) already extracts the signatures; the next generator emits one wrapper per BIF that
  converts native values to kernel objects (omitted = OREF_NULL), runs the handler's own return expression and converts back.

Architecture: Tom Dyer. Coding: ChatGPT / Claude. Writer: Sonnet 5.5.
