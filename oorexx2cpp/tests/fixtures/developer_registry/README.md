# Object-lane acceptance fixture: developer_registry

Origin: written by Gemini (5th attempt; earlier attempts were not valid ooRexx) and verified here against
ooRexx 5.3.0 r13196: runs cleanly, output in `developer_registry.expected` (exit status 0).

Exercises: `::class`, `::attribute` (GET/SET), `::method init` with `expose` + `use arg`, instance method,
`.Array~new` / `.Array~of(...)`, `~append`, `loop dev over team`, `~makeString("L", ", ")`, `"-"~copies(40)`,
a user method named `display`, top-level `exit` before the directives.

Current rx2cpp status (v0.30.3 + Claude increment): rejected at `::class` by the standalone front end
("only ::REQUIRES ... LIBRARY is implemented"). Expected to be the next object-lane target; success = compiled native
output byte-identical to `developer_registry.expected`.

Known-bad sibling (do NOT use): Gemini's attempt 1 calls `.Set~add`, which ooRexx 5.3 does not understand (Error 97.1).
