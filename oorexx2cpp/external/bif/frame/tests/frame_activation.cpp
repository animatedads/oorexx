#include "rxbif_frame_generated.hpp"
#include <cassert>
#include <iostream>
#include <stdexcept>

int main() {
    using namespace rxbif_frame;
    using rxbif_breadth::NumericContext;
    using rxbif_breadth::NumericForm;
    rxbif::Context native;
    FrameSnapshot state{{rx::Value::string("alpha"),std::nullopt,rx::Value::string("gamma"),rx::Value::string("delta")},"COMMAND"};
    NumericContext numeric{9,0,NumericForm::Scientific};
    unsigned numericReads=0, frameReads=0;
    ActivationRouter adapter(native,[&] {++numericReads; return numeric;}, [&] {++frameReads; return state;});
    auto arg=[&](std::vector<Slot> values = {}) {return rxbif_frame_generated::BIF_ARG(adapter,values).bytes;};
    auto addr=[&] {return rxbif_frame_generated::BIF_ADDRESS(adapter).bytes;};
    assert(arg()=="4");
    assert(arg({rx::Value::string("1")})=="alpha");
    assert(arg({rx::Value::string("2")})=="");
    assert(arg({rx::Value::string("3"),rx::Value::string("N")})=="gamma");
    assert(arg({rx::Value::string("2"),rx::Value::string("E")})=="0");
    assert(arg({rx::Value::string("2"),rx::Value::string("O")})=="1");
    assert(arg({rx::Value::string("5"),rx::Value::string("E")})=="0");
    assert(arg({rx::Value::string("5"),rx::Value::string("O")})=="1");
    assert(arg({rx::Value::string("0003"),rx::Value::string("exists")})=="1");
    assert(addr()=="COMMAND");
    state.arguments={rx::Value::string("delta")};
    state.address="REXX";
    numeric={17,2,NumericForm::Engineering};
    assert(arg()=="1");
    assert(arg({rx::Value::string("1")})=="delta");
    assert(addr()=="REXX");
    assert(numericReads==frameReads && numericReads==13);
    auto mustReject=[&](const std::string& reason,std::vector<Slot> args) {
        unsigned before=frameReads;
        try { (void)arg(std::move(args)); throw std::logic_error("failed to reject: "+reason); }
        catch (const std::runtime_error& x) {if(std::string(x.what()).find(reason)==std::string::npos) { std::cerr << "wrong rejection: expected " << reason << " got " << x.what() << "\n"; assert(false); }}
        assert(frameReads==before);
    };
    mustReject("position must be positive",{rx::Value::string("0")});
    mustReject("noncanonical",{rx::Value::string("1.0")});
    mustReject("invalid option",{rx::Value::string("1"),rx::Value::string("X")});
    mustReject("invalid option",{rx::Value::string("1"),rx::Value::string("")});
    mustReject("option requires position",{std::nullopt,rx::Value::string("O")});
    mustReject("array-valued",{rx::Value::string("1"),rx::Value::string("A")});
    numeric={3,3,NumericForm::Scientific};
    try { (void)addr(); assert(false); } catch(const std::runtime_error&) {}
    numeric={9,0,NumericForm::Scientific};
    state.address="";
    try { (void)addr(); assert(false); } catch(const std::runtime_error&) {}
    state.address="COMMAND";
    try { (void)adapter.invoke("TRACE"); assert(false); } catch(const std::runtime_error&) {}
    state.arguments={rx::Value::string("a"),rx::Value::fromObject(std::make_shared<rx::ObjectDispatch>())};
    assert(arg({rx::Value::string("2"),rx::Value::string("E")})=="1");
    assert(arg({rx::Value::string("2"),rx::Value::string("O")})=="0");
    try { (void)arg({rx::Value::string("2")}); assert(false); } catch(const std::runtime_error&) {}
    std::cout<<"PASS source-derived ARG scalar and ADDRESS compiled-frame adapters; dynamic numerics; fail-closed object/array/unsupported semantics\n";
}
