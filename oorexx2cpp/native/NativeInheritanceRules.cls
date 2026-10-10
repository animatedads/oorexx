/* Compiler rules for a qualified within-package inheritance graph.
   Scope membership belongs to classes, not activation depth. The runtime
   retains distinct stable slots for classes, and ooRexx owns dispatch.
   Repeated mixin paths that would alias a native scope are rejected.
*/
::class RxNativeInheritanceRules public
::method validate
  use arg unit, names, definitions, roots, scopes
  parent = unit~parentName
  className = unit~className
  if parent == '' then do
    root = className
    ancestry = .array~new
  end
  else do
    if \names~hasIndex(parent) then self~reject('parent must precede child: ' || parent)
    root = roots[parent]
    ancestry = .array~new
    do member over scopes[parent]
      ancestry~append(member)
    end
  end
  seenMixins = .directory~new
  do mixin over unit~mixinNames
    if seenMixins~hasIndex(mixin) then self~reject('duplicate inherited mixin ' || mixin)
    seenMixins[mixin] = .true
    if mixin == className then self~reject('recursive INHERIT ' || mixin)
    if \names~hasIndex(mixin) then self~reject('unknown or forward mixin ' || mixin)
    if \definitions[mixin]~isMixin then self~reject('INHERIT target is not a MIXINCLASS: ' || mixin)
    if roots[mixin] \== root then self~reject('mixin uses a different native root: ' || mixin)
    if mixin == parent then self~reject('INHERIT duplicates direct parent ' || mixin)
    do inherited over scopes[mixin]
      if inherited == root then iterate
      if ancestry~hasItem(inherited) then
        self~reject('duplicate class occurrence in mixin graph: ' || inherited)
      ancestry~append(inherited)
    end
  end
  if unit~isMixin & parent == '' then self~reject('MIXINCLASS requires a parent')
  ancestry~append(className)
  scopes[className] = ancestry
  return .true
::method reject private
  use arg message
  raise syntax 40.1 array('rx2cpp: native inheritance: ' || message)
