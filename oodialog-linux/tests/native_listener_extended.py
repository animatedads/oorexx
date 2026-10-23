# Test fixture: no standalone production listener or relay.
import oodialog_qt as qt
seen = []
def button_event(id, name):
    seen.append((id, name))
    return 42

def edit_event(id, name):
    seen.append((id, name))
    return 17

qt.open_dialog("dev11", 400, 260)
qt.add_button(101, "Save", 15, 15, 90, 30)
qt.add_edit(102, "old", 15, 55, 120, 24)
qt.add_checkbox(103, "Enable", 15, 90, 110, 24)
qt.add_label(104, "Label", 15, 120, 110, 24)
qt.add_combo(105, 150, 55, 120, 24)
qt.bind(101, "CLICKED", button_event)
qt.bind(102, "CHANGE", edit_event)
assert qt.activate(101) == 42
assert qt.last_callback_result() == 42
qt.set_text(102, "new")
assert qt.get_text(102) == "new"
assert qt.last_callback_result() == 17
qt.add_item(105, "one")
assert seen == [(101, "CLICKED"), (102, "CHANGE")], seen
# Rebinding must replace, not accumulate, the previous callback.
qt.bind(101, "clicked", lambda id, name: 91)
assert qt.activate(101) == 91
assert qt.last_callback_result() == 91
try:
    qt.bind(104, "CLICKED", button_event)  # QLabel has no click signal
    raise AssertionError("unsupported event was accepted")
except ValueError:
    pass
try:
    qt.bind(101, "CHANGE", button_event)
    raise AssertionError("unsupported button CHANGE was accepted")
except ValueError:
    pass
qt.close_dialog()
print("PASS native Qt listener event routing and result propagation")