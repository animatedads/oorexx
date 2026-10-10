# v0.23 compiler progress

`PARSE SOURCE source 1 system .`, `PARSE VERSION`, and `PARSE UPPER ARG`
are now supported for standalone command activations, with strict version
marker difference and ASCII casing guard. Other RexxCPS blockers remain,
including its first decimal literal, numeric contexts, command/trace
semantics and internal routines. BIF development stays a separate lane.

---

## v0.21 addition

`PARSE VAR` and `PARSE VALUE ... WITH` blank-delimited templates now have
separate OO Rexx rule-class / C++ helper implementations and nine differential
fixture programs. RexxCPS still uses unsupported `PARSE SOURCE`,
`PARSE VERSION`, `PARSE UPPER ARG`, and positional patterns.
The BIF team remains independent (see BIF_INTERFACE_CHECK.md).

# v0.20 language coverage progression

- SELECT/WHEN/OTHERWISE supported in the standalone backend, with interpreter-
  verified nested blocks, first-match semantics, and separated clause grammar.
- New focused qualification exercises 17 ooTest methods / 44 assertions,
  alongside eight native differential fixtures.
- Official 4.2 SELECT group run under 5.3: 20 tests, **2 version-sensitive
  expectation errors** (34.1 expected, 34.2 observed), not a full green run.
- RexxCPS is still blocked by decimal literals, PARSE, general numerical
  expressions, SIGNAL, LEAVE/ITERATE, and internal activation; SELECT does
  not remove these independent blockers.
- BIFs remain owned and delivered by a separate development lane.

---

# v0.17 next compiler work

1. Mixin dispatch and class-owned object variables now compile for a
   conservative parent-first, same-root graph. Official ooTest coverage is
   still a discovery/qualification priority. See native/MIXIN_SCOPE.md.
2. Expand method bodies to support explicit `SUPER`, `FORWARD` and safe
   method-to-method message sends, preserving their actual activation scope.
3. Introduce native library activation tracking for derived `INIT`, final
   cleanup, and independent `COPY`, without aliasing native object tokens.
4. Implement checked int64 fast paths plus context-aware BigInt promotion:
   static context/literal analysis, runtime guards, and exact numeric output.
   General decimal arithmetic requires a separate decimal representation;
   BigInt alone does not satisfy NUMERIC DIGITS / FUZZ / FORM.
5. Resume upstream ooTest groups and Crypto's public interface and algorithms
   once those features have interpreter/native parity.

## v0.22 change

Absolute and relative PARSE positional patterns, quoted delimiters and dynamic `(variable)` delimiter patterns have narrow native/interpreter differential coverage. RexxCPS still needs PARSE SOURCE, VERSION, UPPER ARG and comma-delimited ARG templates, plus decimal numerics and internal routines. No BIF code was imported in this lane.

## v0.26 internal routines

Literal labels, routine CALL, expression invocation, RETURN and USE ARG work in a bounded standalone subset. PROCEDURE/EXPOSE, SIGNAL ON NOVALUE, decimal arithmetic, TRACE/ADDRESS and BIF integration remain unimplemented. The original RexxCPS 2.2 remains rejected; the small routine fixtures do not produce a quotable RexxCPS score.
