"""Dev13 Qt/Python listener lifecycle regression (test fixture only)."""
import oodialog_qt as qt

qt.open_dialog("Listener lifetime", 260, 140)
qt.add_button(101, "Go", 8, 8, 90, 30)
seen = []

def replacing(control_id, event):
    seen.append(("first", control_id, event))
    qt.bind(control_id, event, succeeding)
    return 11

def succeeding(control_id, event):
    seen.append(("second", control_id, event))
    assert qt.unbind(control_id, event) is True
    assert qt.unbind(control_id, event) is False
    return 22

assert qt.listener_count() == 0
qt.bind(101, "CLICKED", replacing)
assert qt.listener_count() == 1
assert qt.activate(101) == 11
assert qt.listener_count() == 1
assert qt.activate(101) == 22
assert qt.listener_count() == 0
assert qt.activate(101) is None
assert seen == [("first", 101, "CLICKED"), ("second", 101, "CLICKED")]
qt.close_dialog()
print("PASS dev13 reentrant callback replacement and unbind")
