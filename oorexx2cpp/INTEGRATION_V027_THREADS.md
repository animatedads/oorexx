# v0.27 + Claude threading/operators — labelled integration (separate from v0.27 itself)

Base: rx2cpp_oorexx_v0.27_language (unmodified; the patch `claude_threads_ops_on_v027.patch` applies with `patch -p1`).

Adds: `GUARDED|UNGUARDED` method options + scope lock + compiled `SELF~sel[(arg)]` sends in the native class backend
(threads v0.3); `||`, `&`, `&&` (ExprConcat; `&` tighter than `|`/`&&`, carried by the existing ExprLogical which
now takes an optional inner parser); exact 0/1 `condition()`.
Tests added: tests/test_concat.sh, tests/test_logic.sh, native/test_threads.sh, native/test_selfsend.sh
(native ones need OO_ROOT).

Verified on the supplied ooRexx 5.3.0 r13196, g++ and clang++: tests/run.sh, test_logic, test_concat, test_procedures,
test_internal_routines, test_do_while_forever, test_select, test_parse, test_parse_context, test_compound,
test_rexxcps_structural, test_thread_corpus (14 interpreter / 14 compiler fail-closed), native/test_threads,
native/test_selfsend, test_package, test_inheritance, test_mixin, native/test.sh — all rc=0.

Not done: GUARD ON WHEN, REPLY, compiled-body deadlock (98.905); threaded behaviour of PROCEDURE routines.
