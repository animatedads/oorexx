/*----------------------------------------------------------------------------*/
/* OodBoundGraph.cls -- the mapped-object lines of a bound design, for the    */
/* Database Lab's graph (ChatGPT's): OBJECT and PART lines from               */
/* ObjectStore~graphLines (sphere mapped-objects, article graph-lines).       */
/*                                                                            */
/* Architecture: Tom Dyer.  Code: Claude (Opus 5.5).                          */
/*                                                                            */
/* Run in a session of its own that has the design's data files (the mapped  */
/* objects package and its closure, the object's .cls, its databases), as a   */
/* bound run has: the designer's own session does not load them.             */
/*----------------------------------------------------------------------------*/

-- The graph lines of class clsName (in file) mapped over databases, given as
-- the form's DATABASES: "name=folder ..." (a relative folder is taken from
-- the current directory, where the data files are).  The class's parts'
-- classes are mapped with it, so their lines come too.
::routine oodBoundGraph public
  use strict arg file, clsName, databases
  store = .ObjectStore~new
  do pair over databases~space~makeArray(" ")
    parse var pair name "=" folder
    if folder == "" then folder = name
    store~attach(name, .File~new(folder)~absolutePath)
  end
  cls = .context~package~loadPackage(file)~findClass(clsName)
  if cls == .nil then raise syntax 93.900 array(clsName "is not a class of" file)
  store~map(cls)
  return store~graphLines

::requires "MappedObjects.cls"
