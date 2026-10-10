#include "rxbif.hpp"
#include "rxbif_breadth.hpp"
#include <fstream>
#include <iostream>
#include <stdexcept>
static std::string decode(const std::string &s) {
    if(s.size()%2)throw std::runtime_error("bad hex");
    std::string out;out.reserve(s.size()/2);
    auto d=[](unsigned char c)->int {if(c>='0'&&c<='9')return c-'0';if(c>='A'&&c<='F')return c-'A'+10;throw std::runtime_error("bad hex");};
    for(size_t i=0;i<s.size();i+=2)out+=char((d(s[i])<<4)|d(s[i+1]));
    return out;
}
int main(int argc,char **argv) {
    if(argc!=3)return 64;
    std::ifstream in(argv[1]);if(!in)return 65;
    const std::string mode=argv[2];
    rxbif::Context native;
    rxbif_breadth::Context ctx(native);  // No interpreter callback installed.
    std::string hex;
    while(std::getline(in,hex)) {
        try {
            const auto v=rx::Value::string(decode(hex));
            const auto result=mode=="direct"
              ? rxbif::invoke("SIGN",{v},native)
              : rxbif_breadth::invoke("SIGN",{v},ctx);
            std::cout<<result.bytes<<'\n';
        } catch(const rxbif::NativeSubsetUnsupported&) {
            std::cout<<"U\n"; // Never acceptable for an invalid number.
        } catch(const std::exception&) {
            std::cout<<"E\n";
        }
    }
}
