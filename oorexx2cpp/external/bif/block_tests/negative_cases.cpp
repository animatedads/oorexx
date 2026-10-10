#include "rxbif.hpp"
#include <stdexcept>
#include <string>
#include <vector>
static void check(const std::string &name,const std::vector<std::string> &args,bool expectedFallback){
    std::vector<rx::Value> a;for(const auto &s:args)a.push_back(rx::Value::string(s));rxbif::Context c;
    bool raised=false, fallback=false;
    try {(void)rxbif::invoke(name,a,c);}
    catch(const rxbif::NativeSubsetUnsupported &){raised=true;fallback=true;}
    catch(const std::runtime_error &){raised=true;}
    if(!raised || fallback!=expectedFallback)
       throw std::runtime_error("wrong exception classification for "+name+" value="+args.back());
}
int main(){
  for(const auto &n:std::vector<std::string>{"LEFT","RIGHT","COPIES","WORD","DELSTR","SUBSTR"}){
    for(const auto &v:std::vector<std::string>{"garbage","-1","2.1","1.000000001"})check(n,{"abc",v},false);
    for(const auto &v:std::vector<std::string>{"2.0","2E0"})check(n,{"abc",v},true);
  }
  for(const auto &n:std::vector<std::string>{"POS","LASTPOS"}){
    for(const auto &v:std::vector<std::string>{"garbage","-1","2.1","1.000000001"})check(n,{"a","abc",v},false);
    for(const auto &v:std::vector<std::string>{"2.0","2E0"})check(n,{"a","abc",v},true);
  }
  return 0;
}
