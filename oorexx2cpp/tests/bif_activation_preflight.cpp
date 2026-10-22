#include "rx_bif_integration.hpp"
#include <cassert>
#include <iostream>
#include <memory>
#include <stdexcept>
using rx::Value;
using rx::BifSlot;
static Value call(rx::BifRuntime& b, rx::Variables& vars,
                  const std::string& name, std::vector<BifSlot> args) {
    return rx::dispatchBif(b,vars,name,args);
}
static void reject(rx::BifRuntime& b,rx::Variables& vars,
                   const std::string& name,std::vector<BifSlot> args) {
    bool threw=false;
    try {(void)call(b,vars,name,std::move(args));}
    catch(const std::runtime_error&) {threw=true;}
    assert(threw);
}
int main() {
    rx::BifRuntime b;
    rx::Variables parent;
    rx::set(parent,"X",Value::string("outer"));
    rx::set(parent,"STEM.",Value::string("base"));
    rx::Variables child(parent,{"X","STEM."});
    rx::set(child,"I",Value::string("foo"));
    assert(call(b,child,"VALUE",{Value::string("x")}).bytes=="outer");
    assert(call(b,child,"VALUE",{Value::string("x"),Value::string("new")}).bytes=="outer");
    assert(rx::get(parent,"X").bytes=="new");
    assert(call(b,child,"SYMBOL",{Value::string("stem.i")}).bytes=="VAR");
    assert(call(b,child,"VAR",{Value::string("stem.i")}).bytes=="1");
    assert(call(b,child,"VALUE",{Value::string("stem.i")}).bytes=="base");
    (void)call(b,child,"VALUE",{Value::string("stem.i"),Value::string("changed")});
    assert(rx::getSymbol(parent,"STEM.I").bytes=="base");
    assert(rx::get(parent,"STEM.foo").bytes=="changed");
    assert(call(b,child,"VALUE",{Value::string("123")}).bytes=="123");
    assert(call(b,child,"SYMBOL",{Value::string("x+")}).bytes=="BAD");
    assert(call(b,child,"VAR",{Value::string("x+")}).bytes=="0");
    reject(b,child,"VALUE",{Value::string("x+"),Value::string("write")});
    assert(rx::get(parent,"X").bytes=="new");
    reject(b,child,"VALUE",{Value::string("x"),Value::string("bad"),Value::string("ENVIRONMENT")});
    assert(rx::get(parent,"X").bytes=="new");
    reject(b,child,"VALUE",{Value::string("123"),Value::string("bad")});
    assert(call(b,child,"VALUE",{Value::string("123")}).bytes=="123");
    // A variable holding an object: VALUE answers the object and assigns the new value (BuiltinFunctions VALUE).
    rx::set(parent,"X",Value::fromObject(std::make_shared<rx::ObjectDispatch>()));
    assert(call(b,child,"VALUE",{Value::string("x"),Value::string("bad")}).isObject());
    assert(rx::get(parent,"X").bytes=="bad");
    rx::set(parent,"X",Value::string("safe"));
    child.numeric.digits=17;
    child.numeric.fuzz=2;
    child.numeric.engineering=true;
    assert(call(b,child,"VALUE",{Value::string("x")}).bytes=="safe");
    child.numeric.fuzz=17;
    reject(b,child,"VALUE",{Value::string("x")});
    assert(rx::get(parent,"X").bytes=="safe");
    child.numeric.fuzz=2;
    assert(call(b,child,"VAR",{Value::string("x")}).bytes=="1");
    // TRACE() is language state owned by the compiled program (as the interpreter: N by default), not a rejected BIF.
    assert(call(b,child,"TRACE",{}).bytes=="N");
    std::cout << "PASS activation variable provider: aliases, stem tails, object values, numeric, selectors\n";
}
