# Test fixture only, not a production relay or event-listener application.
import oodialog_qt as qt
seen = []
def listener(control_id, event):
    seen.append((control_id,event))
qt.open_dialog('native bridge test', 320, 160)
qt.add_button(101, 'Save', 15, 15, 80, 32)
qt.bind(101, "CLICKED", listener)
qt.activate(101)
assert seen == [(101, 'CLICKED')], seen
qt.close_dialog()
print('PASS native Qt->Python callable listener')