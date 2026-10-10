#include "rxbif_breadth.hpp"
#include <cassert>
#include <iostream>
#include <stdexcept>
using namespace rxbif_breadth;
int main() {
    rxbif::Context native;
    std::size_t delegated=0, sampled=0;
    NumericContext current{9,0,NumericForm::Scientific};
    Context ctx(native,[&](const std::string& name,const std::vector<Slot>& args,
                            const NumericContext& num) -> rx::Value {
        ++delegated;
        assert(num.digits == current.digits && num.fuzz == current.fuzz && num.form == current.form);
        if (name == "COUNTSTR") {
            assert(args.size()==2); return rx::Value::string("0");
        }
        if (name == "POS") {
            assert(args.size()==4); return rx::Value::string("1");
        }
        assert(false && "unexpected fallback");
        return rx::Value::string("BAD");
    },std::nullopt,[&]{++sampled;return current;});
    // Qualified native call must not delegate or require a numeric snapshot.
    assert(invoke("REVERSE",{rx::Value::string("abc")},ctx).bytes=="cba");
    assert(delegated==0 && sampled==0);
    // A known unimplemented subset is a typed coverage miss and delegates once.
    assert(invoke("COUNTSTR",{rx::Value::string(""),rx::Value::string("aaa")},ctx).bytes=="0");
    assert(delegated==1 && sampled==1);
    current={17,2,NumericForm::Engineering};
    assert(invoke("POS",{rx::Value::string("a"),rx::Value::string("abc"),rx::Value::string("1"),rx::Value::string("2")},ctx).bytes=="1");
    assert(delegated==2 && sampled==2);
    // Real call errors must not cause a second execution through another runtime.
    try { (void)invoke("DATE",{rx::Value::string("Z")},ctx); assert(false); }
    catch(const rxbif::NativeSubsetUnsupported&) { assert(false && "invalid style was mislabeled as unsupported"); }
    catch(const std::runtime_error&) {}
    try { (void)invoke("LEFT",{rx::Value::string("abc"),rx::Value::string("2"),rx::Value::string("xy")},ctx); assert(false); }
    catch(const rxbif::NativeSubsetUnsupported&) { assert(false && "bad pad mislabeled"); }
    catch(const std::runtime_error&) {}
    assert(delegated==2 && sampled==2);
    // The same explicitly unsupported case without a callback remains rejected.
    Context noHost(native);
    try { (void)invoke("COUNTSTR",{rx::Value::string(""),rx::Value::string("b")},noHost); assert(false); }
    catch(const rxbif::NativeSubsetUnsupported&) {}
    // No numeric context: known coverage misses MUST NOT call host handler.
    Context noNumeric(native,[&](const std::string&, const std::vector<Slot>&,const NumericContext&) -> rx::Value {
        assert(false && "host must not execute without NUMERIC snapshot"); return rx::Value::string("BAD");
    });
    try { (void)invoke("COUNTSTR",{rx::Value::string(""),rx::Value::string("b")},noNumeric); assert(false); }
    catch(const std::runtime_error&) {}
    std::cout << "PASS v0.9 strict native fallback classification, dynamic NUMERIC and no duplicate execution\n";
}
