# Kernel spike: compile the real ooRexx source in

Result (ooRexx 5.3.0 source, gcc, 2 cores): `rexx` + `rexxapi` build as static libraries from the unmodified source tree
(only `SHARED` -> `STATIC` in a copy of CMakeLists.txt). `direct_call.cpp` links them into a 2.2 MB program, starts the kernel
with `RexxCreateInterpreter`, enters it with `ApiContext`, and calls `RexxString::substr(n, length, pad)` directly:

    substr('hello',2,,'*')   -> ello      (omitted length = OREF_NULL; the kernel applies the default)
    substr('hello',2,6,'*')  -> ello**

`builtin_call.cpp` goes one level up: it puts the arguments on a real kernel `ExpressionStack` (omitted = NULL) and calls the
compiled-in handler `builtin_function_NAME(context, argcount, stack)` itself. Output equals the interpreter, including its errors:

    substr('hello',2,,'*') -> ello        pos('b','abcb',,3) -> 2        x2d('ff') -> 255
    left('abc',,'*')       -> Error 40.5 (length IS required at run time although the source macro says optional_integer)

That last line is the point: a hand-built defaults table would have been wrong; the real handler is right by construction.
Kernel errors arrive as a C++ exception (`NativeActivation*`); the integration must run calls inside an activation that traps it.

Findings
- The kernel restores a saved image (`rexx.img`) at start-up (BASEIMAGE; searched in the library location, cwd, PATH).
  Missing image = SIGILL in `Interpreter::logicError("cannot locate startup image")`. Build target `rexx_img` makes it.
  Later: embed the image in the output binary so a compiled program is a single file.
- BIF handlers in `BuiltinFunctions.cpp` are thin: argument macros then `return string->substr(n, length, pad);`.
  `bif2signature.rex` (external/bif) already extracts the signatures; the next generator emits one wrapper per BIF that
  converts native values to kernel objects (omitted = OREF_NULL), runs the handler's own return expression and converts back.

Architecture: Tom Dyer. Coding: ChatGPT / Claude. Writer: Sonnet 5.5.
