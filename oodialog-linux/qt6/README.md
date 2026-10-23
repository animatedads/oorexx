# Qt6 Widgets native renderer — experimental development cycle 5

Build on a Linux host with Qt6 Widgets development packages and CMake:

    cmake -S qt6 -B build-qt6
    cmake --build build-qt6 -j
    QT_QPA_PLATFORM=offscreen ./build-qt6/oodialog-qt6 --self-test fixtures/widgets_v4.json
    ./build-qt6/oodialog-qt6 fixtures/widgets_v4.json

On Debian / Ubuntu, use packages `qt6-base-dev`, `cmake`, and a C++ compiler.

The process reads V4-format RC JSON. It emits JSON-lines `ready` and `event` messages on standard output. It accepts JSON-lines commands from standard input, e.g.:

    {"action":"setText","id":105,"value":"Hello"}
    {"action":"addItem","id":106,"value":"Item A"}
    {"action":"addItem","id":107,"value":"Item B"}
    {"action":"setValue","id":109,"value":60}
    {"action":"activate","id":101}
    {"action":"quit"}

Control ID collisions and unresolved IDs are rejected before native control creation. Supported rendering: button, edit, label, checkbox, radio, list, combo, group, progress. Unrecognized RC control types are counted as unsupported (not silently substituted).

**Important:** This is a native Qt process prototype, NOT an ooRexx ABI plugin and not yet connected to `ooDialog.cls` or V5 runtime events. The protocol allows a subsequent ooRexx bridge to dispatch events, but no current claim of seamless `::requires` graphical execution is made. RC dialog unit conversion is currently approximate and must be made font-aware before parity claims. `CONTROL` declarations and advanced owner-draw / Windows-specific resources are not implemented. `--self-test` exercises widget construction and parenting; it cannot prove a Linux GUI rendering run here because Qt6 dev libraries are absent.


Dev6 extensions: tabs, trees, tables, sliders, spin boxes and multi-line rich edit, plus `inspect` state command. `addItem` supports tabs/tree/table, `select` supports tab/tree/table and `setValue` handles slider/spin. Resource dialect currently still Windows V4. Rendering not compiled in the authoring environment.