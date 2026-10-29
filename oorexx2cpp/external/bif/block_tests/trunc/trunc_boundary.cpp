#include "rxbif_breadth.hpp"
#include <cassert>
#include <iostream>
#include <stdexcept>
int main() {
    rxbif::Context native;
    int digits=2,snapshots=0,delegations=0;
    rxbif_breadth::Context context(native,
        [&](const std::string &name,const std::vector<rxbif_breadth::Slot>&,const rxbif_breadth::NumericContext& n) {
          assert(name=="TRUNC" && n.digits==static_cast<std::size_t>(digits));
          ++delegations;return rx::Value::string("host-value");
        }, {}, [&] { ++snapshots;return rxbif_breadth::NumericContext{
                   static_cast<std::size_t>(digits),0,rxbif_breadth::NumericForm::Scientific}; });
    auto invoke=[&](const std::string& s)->std::string {
        return rxbif_breadth::invoke("TRUNC",{rx::Value::string(s),rx::Value::string("4")},context).bytes.str();
    };
    assert(invoke("1.9999")=="2.0000");
    digits=5;
    assert(invoke("1.9999")=="1.9999");
    assert(snapshots==2 && delegations==0);
    for(const auto& arg:{"xx","1.2.3","1e+","1\n2","1E+999999999garbage"}) {
        bool bad=false;
        try {(void)invoke(arg);} catch(const std::runtime_error&) { bad=true; }
        assert(bad);
    }
    for(const auto& arg:{"junk","-1","+","1,2"}) {
        bool bad=false;
        try { (void)rxbif_breadth::invoke("TRUNC",{rx::Value::string("12"),rx::Value::string(arg)},context); }
        catch(const std::runtime_error&) { bad=true; }
        assert(bad);
    }
    assert(delegations==0);
    assert(rxbif_breadth::invoke("TRUNC",{rx::Value::string("2.3"),rx::Value::string("2.0")},context).bytes=="host-value");
    assert(rxbif_breadth::invoke("TRUNC",{rx::Value::string("2.3"),rx::Value::string("9000")},context).bytes=="host-value");
    assert(delegations==2);
    bool bad=false;
    try {(void)rxbif_breadth::invoke("TRUNC",{std::nullopt},context);} catch(const std::runtime_error&) {bad=true;}
    assert(bad && delegations==2);
    rxbif_breadth::Context absent(native);
    bad=false;
    try {(void)rxbif_breadth::invoke("TRUNC",{rx::Value::string("1.23")},absent);} catch(const std::runtime_error&) {bad=true;}
    assert(bad);
    std::cout<<"TRUNC dynamic numeric, malformed, typed fallback, omitted, missing ctx PASS\n";
}
