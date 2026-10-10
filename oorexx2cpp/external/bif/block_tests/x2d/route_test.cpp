#include "rxbif_breadth.hpp"
#include <cassert>
#include <iostream>
#include <stdexcept>
#include <string>
using namespace rxbif_breadth;
int main() {
    rxbif::Context native;
    int digits=9,reads=0,delegates=0;
    Context ctx(native,[&](const std::string& name,const std::vector<Slot>&,const NumericContext& n){
        assert(name=="X2D" && n.digits==static_cast<std::size_t>(digits));++delegates;
        return rx::Value::string("HOST");
    },{},[&](){++reads;return NumericContext{static_cast<std::size_t>(digits),0,NumericForm::Scientific};});
    auto x=[&](const std::string& hex, const std::string& width){return invoke("X2D",{rx::Value::string(hex),rx::Value::string(width)},ctx).bytes;};
    assert(x("FF","2")=="-1");assert(x("FF","3")=="255");
    assert(x("ZZ","0")=="0");assert(x("ABC","2")=="-68");
    assert(x("FFFF","4")=="-1");assert(x("FF","1")=="-1");
    assert(invoke("X2D",{rx::Value::string("FF")},ctx).bytes=="255");
    assert(reads==7 && delegates==0);
    digits=2;bool rejected=false;
    try {(void)x("FF","3");} catch(const std::runtime_error& e){rejected=std::string(e.what()).find("NUMERIC DIGITS")!=std::string::npos;}
    assert(rejected && delegates==0);
    digits=9;
    for(const auto& hex:{"junk"," FF","F ","F G"}) {
        bool bad=false;try{(void)x(hex,"1");}catch(const std::runtime_error&){bad=true;}
        assert(bad && delegates==0);
    }
    bool bad=false;
    try{(void)invoke("X2D",{std::nullopt},ctx);}catch(const std::runtime_error&){bad=true;}
    assert(bad && delegates==0);
    assert(x("FF","1.0")=="HOST" && delegates==1);
    Context without(native);
    bad=false;try{(void)invoke("X2D",{rx::Value::string("AB")},without);}catch(const std::runtime_error&){bad=true;}
    assert(bad);
    std::cout<<"X2D dispatch PASS live precision, signed width, invalid no retry, typed host fallback\n";
}
