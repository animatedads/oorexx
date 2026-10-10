#include "rxbif_syssleep.hpp"
#include <cassert>
#include <chrono>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
using namespace rxbif_external;
static std::uint64_t observed=~std::uint64_t{0};
static int mocked(std::uint64_t us) { observed=us;return 0; }
static int interrupted(std::uint64_t us) {observed=us;return EINTR;}
static rx::Value value(std::string s){return rx::Value::string(s);}
static void invalid(std::string s,int minor) {
    observed=~std::uint64_t{0};bool caught=false;
    try {(void)sysSleep({value(std::move(s))},mocked);}
    catch(const ArgumentError& e){caught=e.rexxMajor()==88&&e.rexxMinor()==minor;}
    assert(caught && observed==~std::uint64_t{0});
}
int main(){
    for(auto [s,us]:std::vector<std::pair<std::string,std::uint64_t>>{
       {"0",0},{"-0",0},{"+ 0",0},{"0e500",0},{".0000009",0},
       {"0.001234",1234},{"0.1",100000},{"  + 0.01  ",0},
       {"1e-500",0},{"2147483",2147483000000ULL}}){
       assert(sysSleep({value(s)},mocked).bytes=="0");assert(observed==us);
    }
    assert(isRexxUtilRoutine("SysSleep") && isRexxUtilRoutine("SYSSLEEP"));
    assert(!isRexxUtilRoutine("SIGN"));
    assert(invokeRexxUtil("syssleep",{value(".01")},mocked).bytes=="0");
    assert(observed==10000);
    assert(sysSleep({value("0.01")},interrupted).bytes==std::to_string(EINTR));
    assert(observed==10000);
    for(const auto& s : {"junk","1 2","1e+","NaN","Infinity","0x1","1e500"})invalid(s,902);
    invalid(std::string("1\0",2),902);
    for(const auto& s : {"-0.001","-1","2147484","2147483.001"})invalid(s,907);
    auto checkArity=[](const std::vector<Slot>& args,int minor) {
        bool caught=false;
        try{(void)sysSleep(args,mocked);}catch(const ArgumentError& e){caught=e.rexxMinor()==minor;}
        assert(caught);
    };
    checkArity({},901);checkArity({std::nullopt},901);
    checkArity({value("0"),value("0")},922);
    // Integration smoke: real nanosleep, generous deadline (not a scheduler promise).
    auto start=std::chrono::steady_clock::now();
    assert(sysSleep({value("0.015")}).bytes=="0");
    auto actual=std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now()-start).count();
    assert(actual>=10 && actual<2000);
    std::cout<<"SYSSLEEP PASS scalar, micros, range, errors, EINTR, 15ms actual sleep\n";
}
