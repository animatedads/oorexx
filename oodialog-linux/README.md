# ooDialog Linux dev12 — GitHub synchronization and native listener hardening

Target: existing ooDialog applications using `::requires 'ooDialog.cls'` on Linux.

## Current engineering state
- `ooDialog.cls` and Rexx regression corpus retained from dev11.
- Qt6 renderer (`qt6/`) retains 15 widget mappings and the accepted openSUSE protocol self-test baseline.
- `native/` is an in-process CPython/Qt6 module; no production relay Python script or Rexx worker process.
- Event registration now rejects event/control mismatches. Supported pairs in native module: QPushButton/CLICKED, QLineEdit/CHANGE, QCheckBox/CHANGE, QComboBox/SELCHANGE.
- Duplicate listener registration replaces the original; synchronous return values are observable through `activate` and `last_callback_result`.
- Dialog dimensions require positive values.

## Native test (requires Qt6, Python development headers, a display or offscreen plugin)
```
cmake -S native -B build-native
cmake --build build-native -j
QT_QPA_PLATFORM=offscreen PYTHONPATH="$PWD/build-native" python3 tests/native_listener_smoke.py
QT_QPA_PLATFORM=offscreen PYTHONPATH="$PWD/build-native" python3 tests/native_listener_extended.py
```

## Qt renderer regression
```
cmake -S qt6 -B build-qt6
cmake --build build-qt6 -j
python3 qt6/tests/protocol_integration.py --executable ./build-qt6/oodialog-qt6 --fixture fixtures/widgets_extended_v4.json
```

**Important:** A live `oorexxpython` Rexx-object callback has NOT been verified. This package does not yet offer an application-transparent `::requires` native renderer nor 80% upstream ooDialog API parity. The previous out-of-process bridge files were removed from this release; the protocol renderer remains diagnostic.