# Credits

* **Architecture and project direction:** Tom Dyer.
* **Coding:** ChatGPT and Claude, working in separate lanes under Tom's direction.
  * ChatGPT: compiler core, decimal number engine, native object lane (`::class`, `::method`, `::attribute`, `::constant`), built-in function (BIF) add-on.
  * Claude: threading, operators, external libraries (`::requires ... LIBRARY`), hex/binary literals, `//` and `**`, `USE STRICT ARG`, `SIGNAL ON/OFF SYNTAX`, `RAISE SYNTAX`, label/EXIT handling.
* **This repository snapshot and its commit message were prepared by Claude Sonnet 5.5.**
* `fixtures/developer_registry/` — example program written by Gemini (5th attempt), verified against ooRexx 5.3.0 r13196 and kept as an object-lane acceptance target.

Oracle for all differential tests: ooRexx 5.3.0 r13196 (interpreter). Nothing here is a claim of full ooRexx conformance;
see `INTEGRATION_MERGE_V0303.md`, `INTEGRATION_CLAUDE_V0301.md` and `QUALIFICATION_V0303.md` for what was and was not run.
