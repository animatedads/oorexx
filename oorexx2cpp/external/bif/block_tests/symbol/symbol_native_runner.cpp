#include "rxbif_breadth.hpp"
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
static std::string hexdecode(const std::string &s) {
    if (s.size() % 2) throw std::runtime_error("odd test fixture hex");
    std::string out;
    out.reserve(s.size()/2);
    auto d=[](char c) -> unsigned {
        if (c >= '0' && c <= '9') return static_cast<unsigned>(c - '0');
        if (c >= 'A' && c <= 'F') return static_cast<unsigned>(c - 'A' + 10);
        throw std::runtime_error("invalid fixture hex");
    };
    for (std::size_t i=0; i<s.size();i+=2)
        out.push_back(static_cast<char>((d(s[i])<<4)|d(s[i+1])));
    return out;
}
int main(int argc,char **argv) {
    if(argc!=3) return 64;
    std::ifstream in(argv[1]);
    if(!in) return 65;
    rxbif::Context native;
    rxbif_breadth::Context ctx(native); // no interpreter callback deliberately
    std::string hex;
    while(std::getline(in,hex)) {
        auto result = rxbif_breadth::invoke("DATATYPE",{
            rx::Value::string(hexdecode(hex)), rx::Value::string(argv[2])},ctx);
        std::cout<<result.bytes<<'\n';
    }
}
