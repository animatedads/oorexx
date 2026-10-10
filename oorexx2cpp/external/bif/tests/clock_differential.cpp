#include "rxbif.hpp"
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
struct Case { const char *name; std::vector<std::string> args; };
const std::vector<Case> cases={
  {"DATE",{"B","2024-02-29","I"}}, {"DATE",{"D","2024-02-29","I"}},
  {"DATE",{"E","2024-02-29","I"}}, {"DATE",{"F","2024-02-29","I"}},
  {"DATE",{"I","2024-02-29","I"}}, {"DATE",{"L","2024-02-29","I"}},
  {"DATE",{"M","2024-02-29","I"}}, {"DATE",{"N","2024-02-29","I"}},
  {"DATE",{"O","2024-02-29","I"}}, {"DATE",{"S","2024-02-29","I"}},
  {"DATE",{"T","2024-02-29","I"}}, {"DATE",{"U","2024-02-29","I"}},
  {"DATE",{"W","2024-02-29","I"}},
  {"DATE",{"I","738944","B"}},
  {"DATE",{"I","63844761600000000","F"}},
  {"DATE",{"I","1709164800","T"}},
  {"DATE",{"I","20240229","S"}},
  {"DATE",{"I","29 Feb 2024","N"}},
  {"DATE",{"I","29/02/24","E"}},
  {"DATE",{"I","02/29/24","U"}},
  {"DATE",{"I","24/02/29","O"}},
  {"DATE",{"I","2024-02-29","I","/"}},
  {"DATE",{"N","2024-02-29","I","-"}},
  {"DATE",{"S","2024-02-29","I","/"}},
  {"DATE",{"E","2024-02-29","I","-"}},
  {"DATE",{"O","2024-02-29","I","-"}},
  {"DATE",{"U","2024-02-29","I","-"}},
  {"DATE",{"I","2024/02/29","I","/","/"}},
  {"DATE",{"I","29-02-24","E","-","-"}},
  {"DATE",{"I","20240229","I","",""}},
  {"TIME",{"C","13:02:03","N"}}, {"TIME",{"F","13:02:03","N"}},
  {"TIME",{"H","13:02:03","N"}}, {"TIME",{"L","13:02:03","N"}},
  {"TIME",{"M","13:02:03","N"}}, {"TIME",{"N","13:02:03","N"}},
  {"TIME",{"O","13:02:03","N"}}, {"TIME",{"S","13:02:03","N"}},
  {"TIME",{"T","13:02:03","N"}},
  {"TIME",{"N","1:02pm","C"}}, {"TIME",{"N","12:00am","C"}},
  {"TIME",{"N","12:00pm","C"}}, {"TIME",{"N","13","H"}},
  {"TIME",{"N","01:02:03.12","L"}},
  {"TIME",{"L","01:02:03.12","L"}},
  {"TIME",{"N","82","M"}}, {"TIME",{"N","123","S"}},
  {"TIME",{"N","46923000000","F"}},
  {"TIME",{"N","-62135549877","T"}}
};
std::string quote(const std::string& s){std::string q="'";for(char c:s){q+=c;if(c=='\'')q+=c;}return q+"'";}
std::string hex(const std::string&s){const char*h="0123456789ABCDEF";std::string r;for(unsigned char c:s){r+=h[c>>4];r+=h[c&15];}return r;}
int main(int argc,char**argv){
 if(argc==2&&std::string(argv[1])=="--rexx"){
   for(size_t i=0;i<cases.size();i++){
     std::cout<<"say '"<<i<<":' || c2x("<<cases[i].name<<"(";
     for(size_t j=0;j<cases[i].args.size();j++){if(j)std::cout<<",";std::cout<<quote(cases[i].args[j]);}
     std::cout<<"))\n";
   }return 0;
 }
 rxbif::Context c;
 for(size_t i=0;i<cases.size();i++){
   std::vector<rx::Value> a;for(const auto&s:cases[i].args)a.push_back(rx::Value::string(s));
   try{std::cout<<i<<":"<<hex(rxbif::invoke(cases[i].name,a,c).bytes)<<"\n";}
   catch(const std::exception&e){std::cerr<<"clock case "<<i<<" "<<cases[i].name<<": "<<e.what()<<"\n";return 1;}
 }
}
