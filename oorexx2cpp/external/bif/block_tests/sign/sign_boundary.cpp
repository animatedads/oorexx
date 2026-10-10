#include "rxbif.hpp"
#include "rxbif_breadth.hpp"
#include <cassert>
#include <iostream>
#include <stdexcept>
int main() {
    rxbif::Context c;
    // Unsupported, not invalid, only for normalization outside native scope.
    bool unsupported=false;
    try { (void)rxbif::invoke("SIGN",{rx::Value::string("1E+999999999")},c); }
    catch(const rxbif::NativeSubsetUnsupported&) { unsupported=true; }
    assert(unsupported);
    unsigned calls=0, snapshots=0;
    rxbif_breadth::Context ctx(c,
        [&](const std::string &name,const std::vector<rxbif_breadth::Slot>& args,
            const rxbif_breadth::NumericContext &n)->rx::Value {
            assert(name=="SIGN" && args.size()==1 && args[0]);
            assert(n.digits==6+snapshots && n.fuzz==1);
            ++calls;
            return rx::Value::string("delegated-by-owner");
        },{},[&]()->rxbif_breadth::NumericContext{
            return {7+snapshots++,1,rxbif_breadth::NumericForm::Scientific};
        });
    for(unsigned i=0;i<2;++i) {
        auto v=rxbif_breadth::invoke("SIGN",{rx::Value::string("1E+999999999")},ctx);
        assert(v.bytes=="delegated-by-owner");
    }
    assert(calls==2 && snapshots==2);
    // Well-qualified native call must not consult NUMERIC context or chainback.
    assert(rxbif_breadth::invoke("SIGN",{rx::Value::string("  -0.001  ")},ctx).bytes=="-1");
    assert(calls==2 && snapshots==2);
    for(const auto& invalid : {"wibble","1e+","1E+1000000000","-","1\n2"}) {
        bool rejected=false;
        try { (void)rxbif_breadth::invoke("SIGN",{rx::Value::string(invalid)},ctx); }
        catch(const std::runtime_error& e) {
            rejected = dynamic_cast<const rxbif::NativeSubsetUnsupported*>(&e)==nullptr;
        }
        assert(rejected);
    }
    assert(calls==2 && snapshots==2); // Invalid calls never delegate.
    // Missing numeric supplier must fail closed for a genuinely unsupported case.
    rxbif_breadth::Context missing(c,ctx.chainback);
    bool failed=false;
    try { (void)rxbif_breadth::invoke("SIGN",{rx::Value::string("1E+999999999")},missing); }
    catch(const std::runtime_error&) { failed=true; }
    assert(failed);
    // Omitted arguments are rejected, rather than fabricating a zero.
    failed=false;
    try { (void)rxbif_breadth::invoke("SIGN",{std::nullopt},ctx); }
    catch(const std::runtime_error&) { failed=true; }
    assert(failed);
    std::cout<<"SIGN boundary, numeric transport, native/direct-error controls PASS\n";
}
