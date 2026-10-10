#include "rxbif_variables_generated.hpp"
#include <cassert>
#include <iostream>
#include <map>
#include <memory>
#include <stdexcept>
#include <string>
using namespace rxbif_variables;
using rxbif_breadth::NumericContext;
using rxbif_breadth::NumericForm;
using SV=rx::Value;
static std::string upper(std::string s) {
    for(char& c:s) c=static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
    return s;
}
int main() {
    rxbif::Context native;
    NumericContext numeric{9,0,NumericForm::Scientific};
    unsigned numericReads=0, providerReads=0;
    // This is a qualified-provider TEST DOUBLE, NOT a Rexx scope emulator.
    // An integration implementation must call the original activation's
    // variable retriever rather than substitute a map or detached routine.
    std::map<std::string,std::string> values{{"X","first"},{"STEM.","base"},{"STEM.I","part"}};
    bool denySelectors=false;
    VariableRouter router(native,[&] {++numericReads;return numeric;},
        [&](const Request& req,const NumericContext& supplied) -> Reply {
            ++providerReads;
            assert(supplied.digits==numeric.digits && supplied.fuzz==numeric.fuzz && supplied.form==numeric.form);
            const std::string key=upper(req.name);
            if (req.action==Action::Classify) {
                if (key=="X+" || key.empty()) return {SymbolKind::Invalid,false,std::nullopt};
                if (key=="123") return {SymbolKind::Literal,false,std::nullopt};
                return {SymbolKind::Assignable,values.find(key)!=values.end(),std::nullopt};
            }
            if (req.selector) {
                if (denySelectors || req.selector->bytes=="ENVIRONMENT")
                    throw std::runtime_error("BIF VALUE: selector requires authorised provider");
                assert(req.selector->bytes=="");
                return {SymbolKind::Assignable,false,SV::string(".SCOPE")};
            }
            if (key=="X+" || key.empty()) return {SymbolKind::Invalid,false,std::nullopt};
            if (key=="123") return {SymbolKind::Literal,false,SV::string("123")};
            const auto it=values.find(key);
            const std::string old=(it!=values.end())?it->second:
                   ((key=="STEM.HELLO")?values.at("STEM."):key);
            if(req.action==Action::Exchange) {
                assert(req.replacement && !req.replacement->isObject());
                values[key]=req.replacement->bytes;
            }
            return {SymbolKind::Assignable,it!=values.end(),SV::string(old)};
        });
    auto call=[&](const std::string& bif,std::vector<Slot> args){return router.invoke(bif,args).bytes;};
    auto symbol=[&](const std::string& name){return rxbif_variables_generated::BIF_SYMBOL(router,{SV::string(name)}).bytes;};
    auto var=[&](const std::string& name){return rxbif_variables_generated::BIF_VAR(router,{SV::string(name)}).bytes;};
    auto value=[&](const std::string& name) {return rxbif_variables_generated::BIF_VALUE(router,{SV::string(name)}).bytes;};
    std::cout<<symbol("missing")<<" "<<var("missing")<<" "<<value("missing")<<"\n";
    std::cout<<symbol("x")<<" "<<var("x")<<" "<<value("x")<<"\n";
    std::cout<<call("VALUE",{SV::string("x"),SV::string("second")})<<"\n";
    std::cout<<value("x")<<"\n";
    std::cout<<symbol("123")<<" "<<var("123")<<" "<<value("123")<<"\n";
    std::cout<<symbol("x+")<<" "<<var("x+")<<"\n";
    std::cout<<symbol("stem.i")<<" "<<var("stem.i")<<" "<<value("stem.i")<<"\n";
    std::cout<<call("VALUE",{SV::string("stem.i"),SV::string("changed")})<<"\n";
    std::cout<<value("stem.hello")<<"\n";
    std::cout<<symbol("stem.")<<" "<<var("stem.")<<" "<<value("stem.")<<"\n";
    assert(values.at("STEM.I")=="changed");
    assert(call("VALUE",{SV::string("X"),std::nullopt,SV::string("")})==".SCOPE");
    auto mustReject=[&](const std::string& why,const std::string& name,std::vector<Slot> args) {
        unsigned before=providerReads;
        try { (void)call(name,std::move(args)); throw std::logic_error("did not reject"); }
        catch (const std::runtime_error& ex) {if (std::string(ex.what()).find(why)==std::string::npos) throw;}
        assert(providerReads==before);
    };
    mustReject("incorrect argument count","VALUE",{});
    mustReject("name must be supplied","SYMBOL",{std::nullopt});
    mustReject("incorrect argument count","VAR",{SV::string("X"),SV::string("y")});
    mustReject("unqualified symbol name","VALUE",{SV::fromObject(std::make_shared<rx::ObjectDispatch>())});
    mustReject("object-valued assignment","VALUE",{SV::string("X"),SV::fromObject(std::make_shared<rx::ObjectDispatch>())});
    mustReject("selector object conversion","VALUE",{SV::string("X"),std::nullopt,SV::fromObject(std::make_shared<rx::ObjectDispatch>())});
    const auto old=values.at("X");
    assert(call("VALUE",{SV::string("123")})=="123");
    // Reject nonassignable write. This test double rejects before mutation.
    try {(void)call("VALUE",{SV::string("123"),SV::string("new")}); assert(false);}
    catch(const std::runtime_error&) {}
    assert(values.at("X")==old);
    try {(void)call("VALUE",{SV::string("X"),std::nullopt,SV::string("ENVIRONMENT")}); assert(false);}
    catch(const std::runtime_error&) {}
    numeric={17,2,NumericForm::Engineering};
    assert(value("X")=="second");
    numeric={3,3,NumericForm::Scientific};
    mustReject("invalid NUMERIC","VAR",{SV::string("X")});
    numeric={9,0,NumericForm::Scientific};
    assert(numericReads>20 && providerReads<numericReads);
    try { (void)router.invoke("TRACE",{}); assert(false); } catch(const std::runtime_error&) {}
    try {VariableRouter missing(native,{},[](const Request&,const NumericContext&){return Reply{};}); assert(false);} catch(const std::invalid_argument&) {}
    try {VariableRouter missing(native,[]{return NumericContext{9,0,NumericForm::Scientific};},{}); assert(false);} catch(const std::invalid_argument&) {}
    std::cerr<<"PASS SYMBOL/VAR/VALUE routed caller-scoped contract, dynamic numeric capture, and fail-closed cases\n";
}
