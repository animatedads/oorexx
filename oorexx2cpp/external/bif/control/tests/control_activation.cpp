#include "rxbif_control_generated.hpp"
#include <cassert>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
using namespace rxbif_control;
using rxbif_breadth::NumericContext;
using rxbif_breadth::NumericForm;
int main(int argc, char** argv) {
    rxbif::Context native;
    NumericContext numeric{9,0,NumericForm::Scientific};
    unsigned numericReads=0, controlReads=0;
    std::string traceSetting="N";
    std::string conditionInstruction="";
    auto supplier=[&]() {++numericReads; return numeric;};
    auto provider=[&](const Request& r,const NumericContext& value) -> rx::Value {
        ++controlReads;
        assert(value.digits==numeric.digits && value.fuzz==numeric.fuzz && value.form==numeric.form);
        switch (r.operation) {
        case Operation::SourceCount: return rx::Value::string("13");
        case Operation::SourceLine:
            if (r.sourceLine != 1) throw std::runtime_error("SOURCELINE original package line out of range");
            return rx::Value::string("/* BIF control-state original interpreter oracle -- exact source line 1 */");
        case Operation::TraceRead: return rx::Value::string(traceSetting);
        case Operation::TraceExchange: {
            if (r.argument != "O" && r.argument != "N")
                throw std::runtime_error("TRACE original activation rejects invalid setting");
            auto prior=traceSetting;
            traceSetting=r.argument;
            return rx::Value::string(prior);
        }
        case Operation::ConditionRead: {
            // The test fixture has no currently trapped condition.
            if (!conditionInstruction.empty()) {
                if (r.argument=="I") return rx::Value::string(conditionInstruction);
                if (r.argument=="C") return rx::Value::string("NOVALUE");
                if (r.argument=="D") return rx::Value::string("THIS_IS_MISSING");
                if (r.argument=="S") return rx::Value::string("OFF");
            }
            return rx::Value::string("");
        }
        case Operation::ConditionReset:
            conditionInstruction.clear();
            return rx::Value::string("");
        }
        throw std::logic_error("unknown control operation");
    };
    ControlRouter bridge(native,supplier,provider);
    auto source=[&](std::vector<Slot> args={}) {return rxbif_control_generated::BIF_SOURCELINE(bridge,args).bytes;};
    auto trace=[&](std::vector<Slot> args={}) {return rxbif_control_generated::BIF_TRACE(bridge,args).bytes;};
    auto condition=[&](std::vector<Slot> args={}) {return rxbif_control_generated::BIF_CONDITION(bridge,args).bytes;};
    if (argc > 1 && std::string(argv[1]) == "--trapped") {
        conditionInstruction="SIGNAL";
        for (const std::string opt : {"I","C","D","E","S","R"})
            std::cout<<opt<<" ["<<condition({rx::Value::string(opt)})<<"]\n";
        std::cout<<"POST ["<<condition({rx::Value::string("I")})<<"]\n";
        return 0;
    }
    std::cout<<"COUNT "<<source()<<"\n";
    std::cout<<"FIRST "<<source({rx::Value::string("1")})<<"\n";
    std::cout<<"TRACE_READ "<<trace()<<"\n";
    std::cout<<"TRACE_PREV "<<trace({rx::Value::string("O")})<<"\n";
    std::cout<<"TRACE_READ2 "<<trace()<<"\n";
    std::cout<<"TRACE_RESET "<<trace({rx::Value::string("N")})<<"\n";
    for (const std::string opt : {"I","C","D","S","E","R"}) {
        std::string result=condition(opt=="I" ? std::vector<Slot>{} : std::vector<Slot>{rx::Value::string(opt)});
        std::cout<<"CONDITION_"<<opt<<" ["<<result<<"]\n";
    }
    numeric={17,2,NumericForm::Engineering};
    assert(source()=="13");
    assert(trace()=="N");
    conditionInstruction="SIGNAL";
    assert(condition({rx::Value::string("instruction")})=="SIGNAL");
    assert(condition({rx::Value::string("reset")})=="");
    assert(conditionInstruction.empty());
    const unsigned before=controlReads;
    auto rejects=[&](const std::string& name,std::vector<Slot> args,const std::string& expected) {
        const unsigned previous=controlReads;
        try {
            (void)bridge.invoke(name,args);
            throw std::logic_error("incorrectly admitted unsupported input: "+name);
        } catch (const std::runtime_error& e) {
            if (std::string(e.what()).find(expected)==std::string::npos)
                throw;
        }
        assert(controlReads==previous);
    };
    rejects("SOURCELINE",{rx::Value::string("0")},"positive");
    rejects("SOURCELINE",{rx::Value::string("1.0")},"unsupported numeric");
    rejects("SOURCELINE",{std::nullopt},"missing or object");
    rejects("TRACE",{rx::Value::fromObject(std::make_shared<rx::ObjectDispatch>())},"missing or object");
    rejects("CONDITION",{rx::Value::string("")},"empty option");
    rejects("CONDITION",{rx::Value::string("X")},"invalid option");
    rejects("CONDITION",{rx::Value::string("A")},"object result ABI");
    rejects("CONDITION",{rx::Value::string("O")},"object result ABI");
    rejects("TRACE",{rx::Value::string("N"),rx::Value::string("O")},"incorrect argument count");
    rejects("SOURCELINE",{rx::Value::string("1"),rx::Value::string("2")},"incorrect argument count");
    assert(before>0);
    try {(void)source({rx::Value::string("14")});assert(false);} catch (const std::runtime_error& e) {
        assert(std::string(e.what()).find("out of range")!=std::string::npos);
    }
    assert(traceSetting=="N");
    try {(void)trace({rx::Value::string("Z")});assert(false);} catch (const std::runtime_error& e) {
        assert(std::string(e.what()).find("invalid setting")!=std::string::npos);
    }
    assert(traceSetting=="N");
    numeric={3,3,NumericForm::Engineering};
    rejects("TRACE",{},"invalid NUMERIC");
    numeric={9,0,NumericForm::Scientific};
    assert(source()=="13");
    try {ControlRouter missing(native, {},provider);assert(false);} catch (const std::invalid_argument&) {}
    try {ControlRouter missing(native, supplier,{});assert(false);} catch (const std::invalid_argument&) {}
    try {(void)bridge.invoke("ADDRESS",{});assert(false);} catch(const std::runtime_error&) {}
    assert(numericReads>controlReads);
    std::cerr<<"PASS BIF control state original-activation contracts; dynamic numerics, atomic trace and condition reset, fail-closed object boundary\n";
}
