# ooDialog/WASM sphere v0.13

Architecture: Tom Dyer. Written by Claude (Fable 5.2). 15 November 2026.

This sphere is the documentation of ooDialog/WASM for other tasks: the designer,
the Qt6 renderer, the binary resource reader, a system-classes file, and anyone
who tests or extends the port.

ooDialog/WASM runs unchanged ooDialog programs in a web browser on Josep Maria
Blasco's ooRexx/WASM runtime. The code is in `animatedads/oorexx`, branch
`oodialog-wasm`, directory `oodialog-wasm/`. Its `README.md` holds the current
figures. This sphere was checked against commit `8fb845d` (v0.27.0).

## Articles

| Read this | When |
|---|---|
| `ops.oodialog-wasm.start` | First. What the port is, its parts, where it lives. |
| `ops.oodialog-wasm.build-and-test` | Before building or running the tests. |
| `ref.oodialog-wasm.renderer-contract` | Before writing a renderer or a tool that drives the page. |
| `ref.oodialog-wasm.seams` | Before building on the port: resources, live dialogs, file names, file dialog. |
| `ops.oodialog-wasm.differences` | Before reporting a behaviour as a fault. |
| `ref.oodialog-wasm.harness` | Before writing a test, or reading sweep.tsv and poke.tsv. |
| `ops.oodialog-wasm.port-a-native` | Before adding a native function. |
| `ref.oodialog-wasm.state` | To see what is done and what is not (a snapshot; the README is current). |
| `ops.oodialog-wasm.lessons` | The faults of this work and the rules that came from them. |

## Read it

    sphere.context {sphereId: "oodialog-wasm"}
    sphere.open {articleId: "ops.oodialog-wasm.start"}

## Check it

    rexx tests/check_sphere.rex .
    GOPHER=/path/to/gopher SPHERE_ZIP=/path/to/sphere.zip sh tests/run.sh

## Keep it current

The sphere gets a new version when the renderer contract, a seam or a
documented difference changes. Each release of the port is announced in the
mailbox lane `oodialog_wasm` with its new ops and events.

## Rebuild it

The articles are data in `sphere-src/articles.py` of the project. After a
release is committed:

    python3 tools/oodsphere.py --gopher PATH/gopher --repo PATH/oorexx-clone --commit COMMIT --out /tmp/sphere

The tool makes this tree with the Sphere Editor, finds the cited lines in the
committed files, validates, lints, packages, and runs both tests. It stops at
the first failure.
