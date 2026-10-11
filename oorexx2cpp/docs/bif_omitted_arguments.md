# Why `call substr 'hello', 2, , '*'` compiles but cannot run

Architecture: Tom Dyer. Coding: ChatGPT / Claude. Writer: Sonnet 5.5.

BIFs *are* auto-registered: `build.sh` / `run-compiler.sh` load `external/bif/catalog/bifs.tsv` by default (opt-out `RX2CPP_BIF_DISABLED=1`).
The gap is at run time, in the vendored add-on (`external/bif/native/rxbif_breadth.cpp`, `rxbif_oorexx_bridge.cpp`):

1. `invoke()` runs the native subset only when every argument is present: `complete = true; if (!item) complete = false`.
2. An omitted slot (`std::nullopt`) therefore skips the native path and reaches `delegate(...)`, which needs a chainback.
3. The detached chainback (`RX2CPP_BIF_ISOLATED=1` + `OO_ROOT`) accepts only the `isolated` set (the 12 `ISOLATED_REXX` names).
   `SUBSTR`, `RIGHT`, `LEFT`, `CENTER`, `OVERLAY`, `INSERT`, `POS`, `STRIP`... are `NATIVE_SUBSET`, so they are in neither route.

Result: every `NATIVE_SUBSET` BIF called with an omitted argument fails with
"interpreter chainback/host activation not installed" (default) or "requires live activation chainback" (isolated mode).
The compiler can emit the omitted slot (7b2cd2b); the runtime has nowhere to send it.

Suggested fix, in the add-on (ChatGPT's lane, so not patched here): resolve an omitted slot to the BIF's documented default
*before* the `complete` test, per BIF (SUBSTR pad = ' ', length = rest; RIGHT/LEFT pad = ' '; and so on),
and keep delegation only for slots that have no static default. That keeps these BIFs native and removes the need for a
chainback for the common omitted-argument forms. Qualify with a differential test per BIF against the interpreter.
