/* Resolver for RxSourceInspector: walks the ::REQUIRES tree depth first. Every dependency goes through the
 * inspector's own neutralisation (prologue relocated, class INIT aliased, LIBRARY refused) into a scratch copy,
 * and the requiring file is pointed at that copy. Nothing from the original tree is loaded or executed.
 */
::class RxRequiresTree public
::attribute inspectors get
::attribute edges get
::attribute missing get
::method init
  expose scratch seen inspectors edges missing counter active
  use arg scratch
  seen = .directory~new; inspectors = .list~new; edges = .list~new; missing = .list~new; counter = 0
  active = .set~new
/* The inspector calls this for each ::REQUIRES; returns the scratch file name, or .nil when not found. */
::method map
  expose scratch seen inspectors edges missing counter active
  use arg name, fromPath
  found = self~locate(name, fromPath)
  if found == '' then do
    missing~append(name)
    return .nil
  end
  edges~append(fromPath || '09'x || found)
  if seen~hasIndex(found) then return seen[found]
  if active~hasItem(found) then raise syntax 40.1 array('rx2cpp inspector: circular ::REQUIRES at ' || found)
  counter += 1
  copy = 'd' || counter || '_' || .File~new(found)~name
  seen[found] = copy
  active~put(found)
  inspector = .RxSourceInspector~new
  inspector~resolver = self
  inspector~inspect(found, scratch || '/' || copy)
  active~remove(found)
  inspectors~append(.array~of(found, inspector))
  return copy
::method locate private
  use arg name, fromPath
  f = .File~new(name, .File~new(fromPath)~parent)
  if f~exists then return f~absolutePath
  f = .File~new(name)
  if f~exists then return f~absolutePath
  found = SysSearchPath('REXX_PATH', name)
  if found == '' then found = SysSearchPath('PATH', name)
  return found
::requires 'inspector/RxSourceInspector.cls'
