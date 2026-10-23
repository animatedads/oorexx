/* Windows RC executable object tree, proof of contract v0.1.
   JSON is declarative data, NEVER evaluated as executable source.
   Dynamic method bodies are fixed templates; handler names are allowlisted. */
::class RcEvent public
::attribute name get
::attribute target get
::attribute payload get
::attribute handled
::method init
  expose name target payload handled
  use arg n,t,p
  name=n; target=t; payload=p; handled=.false

::class RcNode public
::attribute id get
::attribute nodeType get
::attribute parent get
::attribute children get
::attribute properties get
::attribute bindings get
::attribute trace get
::method init
  expose id nodeType parent children properties bindings trace registry
  use arg idArg,typeArg,propertyArg=.nil
  id=idArg~string; nodeType=typeArg~string
  parent=.nil; children=.array~new; bindings=.directory~new
  trace=.array~new; registry=.directory~new
  if propertyArg==.nil then properties=.directory~new
  else properties=propertyArg
::method append
  expose children
  use arg child
  child~attachTo(self)
  children~append(child)
  return child
::method attachTo
  expose parent
  use arg p
  parent=p
::method find
  expose id children
  use arg wanted
  if id==wanted then return self
  do child over children
    found=child~find(wanted)
    if found<>.nil then return found
  end
  return .nil
::method registerHandler
  expose registry
  use arg handlerName, handler
  if handler==.nil then raise syntax 88.900 array('handler required')
  registry[handlerName]=handler
  return self
::method bind
  expose bindings
  use arg eventName,handlerName
  if \self~validName(eventName) | \self~validName(handlerName) then raise syntax 88.900 array('invalid event/handler name')
  if \bindings~hasIndex(eventName) then bindings[eventName]=.array~new
  bindings[eventName]~append(handlerName)
  methodName='on'||eventName~upper~substr(1,1)||eventName~substr(2)
  if \self~hasMethod(methodName) then do
    source=.array~of('use arg payload=.nil','return self~emit("'||eventName||'",payload)')
    self~setMethod(methodName,.Method~new(methodName,source))
  end
  return self
::method validName private
  use arg value
  if value=='' then return .false
  allowed='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_'
  do i=1 to value~length
    if pos(value~substr(i,1),allowed)=0 then return .false
  end
  return .true
::method emit
  expose bindings trace registry parent
  use arg eventName,payload=.nil
  event=.RcEvent~new(eventName,self,payload)
  self~deliver(event)
  return event
::method deliver
  expose bindings trace registry parent
  use arg event
  eventName=event~name
  if bindings~hasIndex(eventName) then do handlerName over bindings[eventName]
    handler=self~lookupHandler(handlerName)
    if handler==.nil then raise syntax 88.900 array('unregistered handler '||handlerName)
    handler~handle(event)
    trace~append(eventName||':'||handlerName)
  end
  if \event~handled & parent<>.nil then parent~deliver(event)
  return event
::method lookupHandler
  expose registry parent
  use arg handlerName
  if registry~hasIndex(handlerName) then return registry[handlerName]
  if parent<>.nil then return parent~lookupHandler(handlerName)
  return .nil
::method toData
  expose id nodeType properties children bindings
  data=.directory~new
  data['id']=id; data['type']=nodeType
  data['properties']=properties
  b=.directory~new
  do name over bindings~allIndexes
    list=.array~new
    do item over bindings[name]; list~append(item); end
    b[name]=list
  end
  data['events']=b
  kids=.array~new
  do child over children; kids~append(child~toData); end
  data['children']=kids
  return data

/* A named, trusted application handler, not JSON source. */
::class RcCountingHandler public
::attribute count get
::attribute lastEvent get
::method init
  expose count lastEvent
  count=0; lastEvent=''
::method handle
  expose count lastEvent
  use arg event
  count=count+1
  lastEvent=event~name

::class RcTreeFactory public
::method fromData class
  use arg source
  return self~makeNode(source)
::method makeNode class private
  use arg source
  props=.directory~new
  if source~hasIndex('properties') then props=source['properties']
  node=.RcNode~new(source['id'],source['type'],props)
  if source~hasIndex('events') then do eventName over source['events']~allIndexes
    do handlerName over source['events'][eventName]
      node~bind(eventName,handlerName)
    end
  end
  if source~hasIndex('children') then do child over source['children']
    node~append(self~makeNode(child))
  end
  return node
::method fromRcJson class
  use arg parsed
  root=.RcNode~new('application','Application')
  do resource over parsed['resources']
    node=self~resourceNode(resource)
    root~append(node)
  end
  return root
::method resourceNode class private
  use arg resource
  node=.RcNode~new(resource['id'],resource['type'],resource)
  if resource~hasIndex('entries') then do entry over resource['entries']
    node~append(self~entryNode(entry))
  end
  return node
::method entryNode class private
  use arg entry
  kind=entry['kind']
  nodeId='line:'||entry['line']
  if kind='control' then do
    args=entry['arguments']
    if args~items>0 then do
      if entry['controlType']='EDITTEXT' then nodeId=args[1]
      else if args~items>1 then nodeId=args[2]
    end
  end
  if kind='menuItem' then do
    nodeId='menu:'||entry['line']
    if entry~hasIndex('resolvedCommandId') then nodeId=entry['resolvedCommandId']~string
  end
  node=.RcNode~new(nodeId,kind,entry)
  if entry~hasIndex('entries') then do child over entry['entries']
    node~append(self~entryNode(child))
  end
  return node

::requires 'json.cls'