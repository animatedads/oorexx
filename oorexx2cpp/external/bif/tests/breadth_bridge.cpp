#include "rxbif_breadth.hpp"
#include "rxbif_oorexx_bridge.hpp"
#include "rxbif_breadth_generated.hpp"
#include <cassert>
#include <iostream>
#include <set>
using namespace rxbif_breadth;
int main(int argc,char** argv) {
    assert(argc==2);
    rxbif::Context native;
    std::size_t called=0;
    const NumericContext original{9,0,NumericForm::Scientific};
    Context host(native,[&](const std::string& name,const std::vector<Slot>&, const NumericContext& numeric) {
        assert(numeric.digits==9 && numeric.fuzz==0 && numeric.form==NumericForm::Scientific);
        ++called;
        return rx::Value::string(name);
    }, original);
    host.preferChainback=true;
    assert(catalog().size()==81);
    std::set<std::string> names;
    for(const Spec& s:catalog()) {
        assert(names.insert(s.name).second);
        std::vector<Slot> args(s.minArgs,rx::Value::string("0"));
        assert(invoke(s.name,args,host).bytes==s.name);
    }
    assert(called==81);
    // Even a registered BIF cannot cross into a host handler without a caller snapshot.
    unsigned countMissing=0;
    Context noNumeric(native,[&](const std::string&, const std::vector<Slot>&, const NumericContext&) {
        ++countMissing; return rx::Value::string("BAD");
    });
    noNumeric.preferChainback=true;
    try { (void)invoke("DIGITS",{},noNumeric); return 12; } catch(const std::runtime_error&) {}
    assert(countMissing==0);
    // Native-subset miss cannot silently fall back under detached defaults.
    noNumeric.preferChainback=false;
    try { (void)invoke("REVERSE",{std::nullopt},noNumeric); return 15; }
    catch (const std::runtime_error&) {}
    assert(countMissing==0);
    Context invalidNumeric(native,[&](const std::string&, const std::vector<Slot>&, const NumericContext&) {
        ++countMissing; return rx::Value::string("BAD");
    }, NumericContext{4,4,NumericForm::Scientific});
    invalidNumeric.preferChainback=true;
    try { (void)invoke("FORMAT",{rx::Value::string("12.3")},invalidNumeric); return 13; } catch(const std::runtime_error&) {}
    assert(countMissing==0);
    // A SINGLE Context lives across multiple calls and nested invocations.
    // The supplier, not an initial snapshot, owns the current NUMERIC frame.
    NumericContext active{9,0,NumericForm::Scientific};
    unsigned sampled=0, delegated=0;
    Context dynamic(native,[&](const std::string& name,const std::vector<Slot>&,
                               const NumericContext& numeric) {
        ++delegated;
        assert(numeric.digits==active.digits && numeric.fuzz==active.fuzz && numeric.form==active.form);
        return rx::Value::string(name+":"+std::to_string(numeric.digits)+":"+std::to_string(numeric.fuzz));
    }, NumericContext{9,0,NumericForm::Scientific}, [&] {
        ++sampled;
        return active;
    });
    dynamic.preferChainback=true;
    assert(invoke("FORMAT",{rx::Value::string("1.234")},dynamic).bytes=="FORMAT:9:0");
    active={4,1,NumericForm::Engineering};
    assert(invoke("FORMAT",{rx::Value::string("1.234")},dynamic).bytes=="FORMAT:4:1");
    active={12,2,NumericForm::Scientific};
    assert(invoke("SIGN",{rx::Value::string("1.234")},dynamic).bytes=="SIGN:12:2");
    // An omitted native argument must use the same dynamic supplier.
    dynamic.preferChainback=false;
    assert(invoke("REVERSE",{std::nullopt},dynamic).bytes=="REVERSE:12:2");
    assert(sampled==4 && delegated==4);
    // Invalid current settings must never be replaced with the stale snapshot.
    active={4,4,NumericForm::Scientific};
    try { (void)invoke("FORMAT",{rx::Value::string("1")},dynamic); return 17; }
    catch(const std::runtime_error&) {}
    assert(delegated==4);
    Context missingDynamic(native,[&](const std::string&, const std::vector<Slot>&,
                                     const NumericContext&) {
        ++delegated; return rx::Value::string("BAD");
    },std::nullopt,[]() -> NumericContext {throw std::runtime_error("numeric source unavailable");});
    missingDynamic.preferChainback=true;
    try { (void)invoke("FORMAT",{rx::Value::string("1")},missingDynamic); return 18; }
    catch(const std::runtime_error&) {}
    assert(delegated==4);
    // Nested pass-throughs must independently capture the active numeric frame.
    NumericContext nestedState{9,0,NumericForm::Scientific};
    unsigned nestedSamples=0;
    Context nested(native,[&](const std::string& name,const std::vector<Slot>&,
                              const NumericContext& observed) -> rx::Value {
        if (name == "FORMAT") {
            assert(observed.digits==9 && observed.fuzz==0);
            nestedState={17,2,NumericForm::Engineering};
            auto inside=invoke("TRUNC",{rx::Value::string("1.234")},nested);
            assert(inside.bytes=="TRUNC:17:2");
            nestedState={9,0,NumericForm::Scientific};
            return rx::Value::string("FORMAT:9:0");
        }
        assert(name=="TRUNC" && observed.digits==17 && observed.fuzz==2 &&
               observed.form==NumericForm::Engineering);
        return rx::Value::string("TRUNC:17:2");
    },std::nullopt,[&] { ++nestedSamples; return nestedState; });
    nested.preferChainback=true;
    assert(invoke("FORMAT",{rx::Value::string("1.234")},nested).bytes=="FORMAT:9:0");
    assert(nestedSamples==2);
    Context noBridge(native);
    assert(invoke("REVERSE",{rx::Value::string("abc")},noBridge).bytes=="cba");
    assert(invoke("LENGTH",{rx::Value::string("abc")},noBridge).bytes=="3");
    try { invoke("ARG",{},noBridge); return 10; } catch(const std::runtime_error&) {}
    try { invoke("SIGN",{rx::Value::string("-1")},noBridge); return 11; } catch(const std::runtime_error&) {}
    IsolatedOoRexx oo(argv[1]);
    const struct {const char* n; std::vector<Slot> a;const char* wanted;} cases[]={
        {"C2D",{rx::Value::string("A")},"65"},
        {"FORMAT",{rx::Value::string("12.5")},"12.5"},
        {"TRUNC",{rx::Value::string("12.9")},"12"},
        {"X2D",{rx::Value::string("FF")},"255"},
        {"D2X",{rx::Value::string("255")},"FF"},
        {"D2C",{rx::Value::string("65")},"A"},
        {"TRANSLATE",{rx::Value::string("abc")},"ABC"},
        {"TRANSLATE",{rx::Value::string("abc"),std::nullopt,rx::Value::string("abc")},"   "},
        {"VERIFY",{rx::Value::string("abc"),rx::Value::string("abc")},"0"},
        {"DATATYPE",{rx::Value::string("42"),rx::Value::string("W")},"1"},
        {"SIGN",{rx::Value::string("-10")},"-1"},
        {"MAX",{rx::Value::string("4"),rx::Value::string("8"),rx::Value::string("2")},"8"},
        {"MIN",{rx::Value::string("4"),rx::Value::string("8"),rx::Value::string("2")},"2"},
        {"XRANGE",{rx::Value::string("a"),rx::Value::string("c")},"abc"}
    };
    for(const auto& t:cases) {
        auto result=oo.call(t.n,t.a, original);
        if(result.bytes!=t.wanted) {
            std::cerr<<t.n<<": expected "<<t.wanted<<" got "<<result.bytes<<"\n";
            return 2;
        }
    }
    assert(!oo.call("USERID",{},original).bytes.empty());
    assert(!oo.call("ERRORTEXT",{rx::Value::string("40")},original).bytes.empty());
    assert(!oo.call("QUALIFY",{rx::Value::string(".")},original).bytes.empty());
    try { oo.call("ARG",{},original); return 3; } catch(const std::runtime_error&) {}
    // A separate interpreter must use the caller's numeric settings, not its defaults.
    struct NumericalCase {NumericContext context; const char* formatted; const char* maximum; const char* truncated;};
    const NumericalCase casesNum[] = {
        {{4,0,NumericForm::Scientific},"1.235E+8","1.235","1.2350"},
        {{17,2,NumericForm::Engineering},"123456789.12345679","1.2345678901234568","1.2345"},
        {{12,1,NumericForm::Scientific},"123456789.123","1.23456789012","1.2345"}
    };
    for (const auto& item : casesNum) {
        const auto numeric=item.context;
        const auto formatted=oo.call("FORMAT",{rx::Value::string("123456789.123456789")},numeric);
        const auto maximum=oo.call("MAX",{rx::Value::string("1.234567890123456789"),rx::Value::string("1.234567890123456788")},numeric);
        const auto truncated=oo.call("TRUNC",{rx::Value::string("1.234567890123456789"),rx::Value::string("4")},numeric);
        assert(formatted.bytes==item.formatted);
        assert(maximum.bytes==item.maximum);
        assert(truncated.bytes==item.truncated);
    }
    try { (void)oo.call("FORMAT",{rx::Value::string("1.23")},NumericContext{0,0,NumericForm::Scientific}); return 14; }
    catch (const std::runtime_error&) {}
    std::cout<<"PASS 81/81 routed via explicit host callback, "<<(sizeof(cases)/sizeof(cases[0])+3)<<" detached ooRexx executions\n";
}
