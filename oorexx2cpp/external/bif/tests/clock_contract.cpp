/* Native DATE/TIME clock contract, including fail-closed paths.
   The source converter and generated .cls remain implemented in ooRexx. */
#include "rxbif.hpp"
#include <chrono>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
using namespace std::chrono;
static std::string clockCall(const std::string& n,std::initializer_list<const char*> in,rxbif::Context&c){
 std::vector<rx::Value> args;
 for(const auto* s:in)args.push_back(rx::Value::string(s));
 return rxbif::invoke(n,args,c).bytes.str();
}
static void check(bool yes,const char*msg){if(!yes)throw std::runtime_error(msg);}
static void reject(const std::string&n,std::initializer_list<const char*>arg,rxbif::Context&c){
 bool threw=false;try{(void)clockCall(n,arg,c);}catch(const std::runtime_error&){threw=true;}
 if(!threw)throw std::runtime_error("incorrectly accepted invalid "+n);
}
int main(){
 rxbif::Context c(system_clock::time_point(seconds(1709164800)));
 // Seeded UTC activation must be immutable for repeated DATE and TIME calls.
 const auto t0=clockCall("TIME",{},c),d0=clockCall("DATE",{},c);
 check(t0==clockCall("TIME",{},c),"activation time changed");
 check(d0==clockCall("DATE",{},c),"activation date changed");
 check(clockCall("DATE",{"B","2024-02-29","I"},c)=="738944","Rexx base-date epoch");
 check(clockCall("DATE",{"I","63844761600000000","F"},c)=="2024-02-29","DATE F roundtrip");
 check(clockCall("DATE",{"I","1709164800","T"},c)=="2024-02-29","DATE T roundtrip");
 check(clockCall("TIME",{"N","46923000000","F"},c)=="13:02:03","TIME F roundtrip");
 check(clockCall("TIME",{"N","-62135549877","T"},c)=="13:02:03","TIME T roundtrip");
 reject("DATE",{"Q","2024-02-29","I"},c);
 reject("DATE",{"I","1900-02-29","I"},c);
 reject("DATE",{"I","2023-02-29","I"},c);
 reject("DATE",{"I","2024-02-29","I","A"},c);
 reject("DATE",{"L","2024-02-29","I","/"},c);
 reject("DATE",{"I","2024-02-29","I","?","long"},c);
 reject("TIME",{"N","24:00:00","N"},c);
 reject("TIME",{"N","86400","S"},c);
 reject("TIME",{"N","0:00pm","C"},c);
 reject("TIME",{"N","not-a-time","N"},c);
 reject("TIME",{"E","13:02:03","N"},c);
 // Elapsed clock is context-local; R resets, E does not.
 check(!clockCall("TIME",{"E"},c).empty(),"elapsed empty");
 check(!clockCall("TIME",{"R"},c).empty(),"reset empty");
 check(!clockCall("TIME",{"E"},c).empty(),"elapsed after reset empty");
 std::cout<<"PASS 21 native DATE/TIME contract checks\n";
}
