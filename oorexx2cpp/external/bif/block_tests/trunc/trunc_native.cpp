#include "rxbif_breadth.hpp"
#include <fstream>
#include <iostream>
#include <string>
#include <stdexcept>
static std::string decode(const std::string &s) {
    if(s.size()%2)throw std::runtime_error("invalid fixture");
    std::string o;
    for(size_t i=0;i<s.size();i+=2) {
        auto dig=[](char c)->unsigned{return c>='0'&&c<='9'? c-'0':c-'A'+10;};
        o.push_back(char(dig(s[i])*16+dig(s[i+1])));
    }
    return o;
}
static std::string encode(const std::string &s) {
    constexpr char hex[]="0123456789ABCDEF";std::string o;
    for(unsigned char c:s) {o+=hex[c>>4];o+=hex[c&15];}
    return o;
}
int main(int argc,char** argv) {
    if(argc!=3)return 64;
    const std::size_t digits=std::stoul(argv[2]);
    std::ifstream in(argv[1]);if(!in)return 65;
    rxbif::Context native;
    std::size_t reads=0;
    rxbif_breadth::Context ctx(native, {},{},[&]{
        ++reads;
        return rxbif_breadth::NumericContext{digits,0,rxbif_breadth::NumericForm::Scientific};
    });
    std::string line;
    while(std::getline(in,line)) {
        auto pos=line.find('|');if(pos==std::string::npos)return 66;
        auto bytes=decode(line.substr(0,pos));auto decimals=line.substr(pos+1);
        std::vector<rxbif_breadth::Slot> args{rx::Value::string(bytes)};
        if(decimals!="-")args.push_back(rx::Value::string(decimals));
        try {
            auto v=rxbif_breadth::invoke("TRUNC",args,ctx);
            std::cout<<"V"<<encode(v.bytes)<<'\n';
        } catch(const std::exception&) {std::cout<<"E"<<'\n';}
    }
    std::cerr<<"precision_reads="<<reads<<"\n";
}
