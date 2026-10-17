#include "native_nine_stub.hpp"
#include <cassert>
#include <iostream>
using namespace rx;
static Value V(const std::string &s){return Value::string(s);}
static MessageResult call(const Value &v,const std::string &s,std::vector<Value> a={}){return v.object->sendMessage(s,a);}
static std::string txt(const MessageResult &m){assert(m && !m->isObject());return m->bytes.str();}
int main() {
 const auto list=*call(nativeNineClass("LIST"),"NEW");
 assert(txt(call(list,"APPEND",{V("one")}))=="0");
 assert(txt(call(list,"APPEND",{V("two")}))=="1");
 assert(txt(call(list,"ITEMS"))=="2");
 assert(txt(call(list,"FIRSTITEM"))=="one");
 const auto queue=*call(nativeNineClass("QUEUE"),"NEW");
 call(queue,"QUEUE",{V("one")});call(queue,"PUSH",{V("two")});
 assert(txt(call(queue,"PEEK"))=="two");assert(txt(call(queue,"PULL"))=="two");
 for(auto name:{"TABLE","SET","BAG","RELATION"}) {
  const auto o=*call(nativeNineClass(name),"NEW");
  call(o,"PUT",std::string(name)=="TABLE"||std::string(name)=="RELATION" ? std::vector<Value>{V("v"),V("key")} : std::vector<Value>{V("key")});
  assert(txt(call(o,"ITEMS"))=="1");
  assert(txt(call(o,"HASINDEX",{V("key")}))=="1");
 }
 const auto d=NativeNineClass("DATETIME");
 assert(d.kind=="DATETIME");
 // Materialization may not dereference a temporary, already-freed EnvObject.
 // The standalone stub gives an uncached fresh EnvObject from every lookup.
 // Run under ASan to detect a regression in the class-reference ownership.
 for(const char *name : {"LIST","QUEUE","TABLE","SET","BAG","RELATION","SUPPLIER","MESSAGE","DATETIME"}) {
  auto classRef=nativeNineClass(name);
  assert(dynamic_cast<NativeNineClass *>(classRef.object.get())->materialize()==nullptr);
 }
 auto dense1=std::make_shared<NativeArray>();dense1->slots={V("x"), V("y")};dense1->count=2;
 auto dense2=std::make_shared<NativeArray>();dense2->slots={V("a"), V("b")};dense2->count=2;
 auto sparse1=std::make_shared<NativeArray>();sparse1->slots={V("x"),std::nullopt,V("z")};sparse1->count=2;
 auto sparse2=std::make_shared<NativeArray>();sparse2->slots={V("a"),std::nullopt,V("c")};sparse2->count=2;
 auto dense=call(nativeNineClass("SUPPLIER"),"NEW",{Value::fromObject(dense1),Value::fromObject(dense2)});
 assert(dense && dynamic_cast<NativeSupplier*>(dense->object.get()));
 auto onlyItemsSparse=call(nativeNineClass("SUPPLIER"),"NEW",{Value::fromObject(sparse1),Value::fromObject(dense2)});
 assert(!onlyItemsSparse); // The mock interpreter cannot service delegated NEW.
 auto bothSparse=call(nativeNineClass("SUPPLIER"),"NEW",{Value::fromObject(sparse1),Value::fromObject(sparse2)});
 assert(!bothSparse);
 std::cout<<"PASS nine native C++ dispatch and Supplier both sparse promotion gates\n";
}
