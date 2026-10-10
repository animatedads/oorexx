#include "rxbif_v028_activation.hpp"
#include "rxbif_v028_extlib.hpp"
#include <cassert>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
using rx::Value;
using rxbif_v028::Slot;
static Slot s(const std::string& x){return Value::string(x);}
static void reject(const std::function<void()>& f){static int caseNo=0; ++caseNo;bool failed=false;try{f();}catch(const std::exception&){failed=true;} if(!failed) std::cerr<<"REJECT unexpectedly accepted #"<<caseNo<<"\n";assert(failed);}
int main(int argc,char**argv){
    rx::BifRuntime native;
    rx::Variables outer;
    rx::set(outer,"X",Value::string("old"));
    rx::set(outer,"S.BAR",Value::string("initial"));
    rx::Variables child(outer,{"X","S."});
    rx::set(child,"I",Value::string("BAR"));
    rx::Variables* current=&outer;
    auto pool=[&]()->rx::Variables*{return current;};
    rxbif_frame::FrameSnapshot frame{{s("first"),std::nullopt,s("third")},"COMMAND"};
    std::string trace="N",condition="";
    bool reset=false;
    std::size_t callbackCount=0;
    auto control=[&](const rxbif_control::Request& req,const rxbif_breadth::NumericContext& numeric)->Value{
        rxbif_breadth::validateNumericContext(numeric);
        ++callbackCount;
        using Op=rxbif_control::Operation;
        switch(req.operation){
          case Op::SourceCount: return Value::string("3");
          case Op::SourceLine: if(req.sourceLine<1 || req.sourceLine>3) throw std::runtime_error("out of range"); return Value::string(req.sourceLine==2?"say 'ok'":"x=1");
          case Op::TraceRead: return Value::string(trace);
          case Op::TraceExchange:{if(req.argument.empty()) throw std::runtime_error("empty trace setting");auto old=trace;trace=req.argument;return Value::string(old);}
          case Op::ConditionRead: return Value::string(req.argument=="I"?condition:"");
          case Op::ConditionReset: reset=true;condition.clear();return Value::string("");
        }
        throw std::runtime_error("unreachable");
    };
    rxbif_v028::Router bridge(native,pool,[&]{return frame;},control);
    auto invoke=[&](const std::string& name,const std::vector<Slot>& args=std::vector<Slot>{})->std::string {return bridge.invoke(name,args).bytes;};
    assert(invoke("digits")=="9"); assert(invoke("fuzz")=="0"); assert(invoke("form")=="SCIENTIFIC");
    outer.numeric.digits=16;outer.numeric.fuzz=3;outer.numeric.engineering=true;
    assert(invoke("DIGITS")=="16");assert(invoke("FUZZ")=="3");assert(invoke("FORM")=="ENGINEERING");
    current=&child; child.numeric.digits=4;child.numeric.fuzz=1;child.numeric.engineering=false;
    assert(invoke("DIGITS")=="4"); assert(invoke("FORM")=="SCIENTIFIC");
    assert(invoke("SYMBOL",{s("x")})=="VAR");
    assert(invoke("VALUE",{s("x"),s("new")})=="old");
    assert(rx::get(outer,"X").bytes=="new");
    assert(invoke("ARG")=="3");
    assert(invoke("ARG",{s("2"),s("O")})=="1");
    assert(invoke("ARG",{s("2"),s("E")})=="0");
    assert(invoke("ARG",{s("1")})=="first");
    assert(invoke("ADDRESS")=="COMMAND");
    frame.address="SYSTEM";assert(invoke("ADDRESS")=="SYSTEM");
    assert(invoke("SOURCELINE")=="3");
    assert(invoke("SOURCELINE",{s("2")})=="say 'ok'");
    assert(invoke("TRACE")=="N");assert(invoke("TRACE",{s("R")})=="N");assert(invoke("TRACE")=="R");
    condition="SIGNAL";assert(invoke("CONDITION")=="SIGNAL");assert(invoke("CONDITION",{s("R")})=="");assert(reset);
    const auto before=callbackCount;
    reject([&]{(void)bridge.invoke("CONDITION",{s("O")});});
    reject([&]{(void)bridge.invoke("TRACE",{s("")});});
    assert(callbackCount==before+1);
    child.numeric.fuzz=4;
    reject([&]{(void)bridge.invoke("DIGITS");});
    reject([&]{(void)bridge.invoke("TRACE");});
    child.numeric.fuzz=1;
    rxbif_v028::Router limited(native,pool);
    reject([&]{(void)limited.invoke("ARG");});
    reject([&]{(void)limited.invoke("CONDITION");});
    current=nullptr;
    reject([&]{(void)bridge.invoke("DIGITS");});
    current=&child;
    rxext::Host host;
    rxbif_v028::TypedHostBridge external(host,pool);
    host.varSet("S.I","symbol-value");
    assert(rx::get(outer,"S.BAR").bytes=="symbol-value");
    auto* stem=host.poolStem("S.");
    stem->set("I","literal-value");
    assert(stem->get("I").value()=="literal-value");
    assert(rx::get(outer,"S.I").bytes=="literal-value");
    assert(host.varGet("S.I").value()=="symbol-value");
    host.tailDrop("S.","I");
    assert(!rx::lookup(outer,"S.I"));
    assert(host.varGet("S.BAD")==std::nullopt);
    reject([&]{host.varSet("123","oops");});
    rx::set(outer,"X",Value::fromObject(std::make_shared<rx::ObjectDispatch>()));
    reject([&]{(void)host.varGet("X");});
    rx::set(outer,"X",Value::string("ok"));
    current=&outer;
    if(argc>1){
        host.searchDirs={argv[1]};host.load("rxmath");
        auto first=external.call("RxCalcSin",{{"0.5",nullptr,false}});
        assert(first && !first->empty());
        assert(host.numeric.digits==16 && host.numeric.fuzz==3 && host.numeric.form==1);
        current=&child;
        auto second=external.call("RxCalcSin",{{"0.5",nullptr,false}});
        assert(second && !second->empty());
        assert(host.numeric.digits==4 && host.numeric.fuzz==1 && host.numeric.form==0);
    }
    child.numeric.fuzz=4;
    reject([&]{(void)external.call("RxCalcSin",{{"0.5",nullptr,false}});});
    std::cout<<"PASS optional BIF v0.28 activation+extlib interoperability\n";
}
