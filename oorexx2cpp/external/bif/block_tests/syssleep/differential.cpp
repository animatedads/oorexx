#include "rxbif_syssleep.hpp"
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
using namespace rxbif_external;
static int digit(char c){if(c>='0'&&c<='9')return c-'0'; if(c>='A'&&c<='F')return c-'A'+10;throw std::runtime_error("bad fixture");}
static std::string decode(const std::string &hex){
 if(hex.size()%2)throw std::runtime_error("bad hex size");
 std::string s;for(size_t i=0;i<hex.size();i+=2)s+=static_cast<char>(digit(hex[i])*16+digit(hex[i+1]));return s;
}
int main(int argc,char**argv){
 if(argc!=2)return 64;
 std::ifstream f(argv[1]);
 if(!f)return 65;
 std::string hex;
 while(std::getline(f,hex)){
    try{
        const auto result=sysSleep({rx::Value::string(decode(hex))});
        std::cout<<"V"<<result.bytes<<"\n";
    }catch(const ArgumentError &e){
        std::cout<<"E"<<e.rexxMajor()<<"."<<e.rexxMinor()<<"\n";
    }
 }
}
