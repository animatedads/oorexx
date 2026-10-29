"""Dev14 validation and lifecycle regression for native Qt module (test only)."""
import oodialog_qt as qt

try:
    qt.open_dialog("Invalid dimensions", 0, 100)
except ValueError:
    pass
else:
    raise AssertionError("width=0 must be rejected")

qt.open_dialog("Valid first dialog", 240, 140)
qt.add_button(110, "OK", 8, 8, 80, 24)
assert qt.listener_count() == 0
seen = []
def click(control_id, event_name):
    seen.append((control_id, event_name))
    return 9
qt.bind(110, "CLICKED", click)
assert qt.activate(110) == 9
assert seen == [(110, "CLICKED")]
qt.close_dialog()

qt.open_dialog("Reopened", 260, 160)
qt.add_button(110, "Again", 8, 8, 80, 24)
assert qt.listener_count() == 0, "listeners leaked across dialog lifetimes"
assert qt.activate(110) is None, "old listener leaked into new dialog"
qt.close_dialog()
print("PASS dev14 validation and close/reopen isolation")
