/* Architecture: Tom Dyer. Code: ChatGPT (GPT-6).                      */
/* Additive ooDialog-compatible native WinUI 3 control proxies.        */
/* Load from an existing ooDialog program using ::requires "OodFluent.cls" */

::class OodFluentHost public

::method attach class
  use strict arg dialog, cataloguePath, experimental = 0
  return self~new(dialog, cataloguePath, experimental)

::method init
  expose dialog token controls
  use strict arg dialog, cataloguePath, experimental = 0
  controls = .directory~new
  token = OodfNativeOpen(dialog~hwnd, cataloguePath, experimental)

::method dialog
  expose dialog
  return dialog

::method newControl
  expose token controls
  use strict arg resourceId, kind, caption = ''
  uid = OodfNativeCreate(token, resourceId, kind, caption)
  control = .OodFluentControl~new(self, resourceId, uid, kind)
  controls[uid] = control
  return control

::method newButton
  use strict arg resourceId, caption = ''
  return self~newControl(resourceId, 'Button', caption)

::method newToggleSwitch
  use strict arg resourceId, caption = ''
  return self~newControl(resourceId, 'ToggleSwitch', caption)

::method newNumberBox
  use strict arg resourceId, caption = ''
  return self~newControl(resourceId, 'NumberBox', caption)

::method newInfoBar
  use strict arg resourceId, message = ''
  return self~newControl(resourceId, 'InfoBar', message)

::method setProperty
  expose token
  use strict arg uid, property, value
  return OodfNativeSet(token, uid, property, value)

::method connectEvent
  expose token
  use strict arg uid, eventName, handler
  return OodfNativeBind(token, uid, eventName, handler)

::method move
  expose token
  use strict arg x, y, width, height
  return OodfNativeMove(token, x, y, width, height)

::method remove
  expose token controls
  use strict arg uid
  result = OodfNativeRemove(token, uid)
  controls~remove(uid)
  return result

::method pollEvent
  expose token
  return OodfNativePoll(token)

::method dispatchPending
  expose dialog
  /* Called from the ooDialog UI-thread message/timer dispatch; never from XAML. */
  use strict arg limit = 64
  if limit < 1 then raise user OodFluent additional ('limit must be positive')
  dispatched = 0
  do limit
    event = self~pollEvent
    if event == .nil then leave
    /* The handler is an ooDialog instance method. */
    dialog~sendWith(event~handler, .array~of(event~resourceId, event~uid, event~value))
    dispatched += 1
  end
  return dispatched

::method close
  expose token controls
  if token == '' then return .false
  result = OodfNativeClose(token)
  token = ''
  controls = .directory~new
  return result

::class OodFluentControl public

::method init
  expose host resourceId uid kind
  use strict arg host, resourceId, uid, kind

::attribute resourceId get
::attribute uid get
::attribute kind get

::method setProperty
  expose host uid
  use strict arg name, value
  return host~setProperty(uid, name, value)

::method setText
  use strict arg text
  return self~setProperty('text', text)

::method setValue
  use strict arg value
  return self~setProperty('value', value)

::method setOn
  use strict arg on
  if on then return self~setProperty('isOn', 'true')
  return self~setProperty('isOn', 'false')

::method setOpen
  use strict arg on
  if on then return self~setProperty('isOpen', 'true')
  return self~setProperty('isOpen', 'false')

::method connectEvent
  expose host uid
  use strict arg eventName, handler
  return host~connectEvent(uid, eventName, handler)

::method remove
  expose host uid
  return host~remove(uid)

::routine OodfNativeOpen external "LIBRARY OodFluentWindows OodfNativeOpen"
::routine OodfNativeCreate external "LIBRARY OodFluentWindows OodfNativeCreate"
::routine OodfNativeSet external "LIBRARY OodFluentWindows OodfNativeSet"
::routine OodfNativeBind external "LIBRARY OodFluentWindows OodfNativeBind"
::routine OodfNativeMove external "LIBRARY OodFluentWindows OodfNativeMove"
::routine OodfNativeRemove external "LIBRARY OodFluentWindows OodfNativeRemove"
::routine OodfNativePoll external "LIBRARY OodFluentWindows OodfNativePoll"
::routine OodfNativeClose external "LIBRARY OodFluentWindows OodfNativeClose"
