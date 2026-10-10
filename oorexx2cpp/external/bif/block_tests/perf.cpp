#include "rxbif.hpp"
#include <chrono>
#include <iostream>
#include <string>
#include <vector>
#include <cstdint>
int main(){
    constexpr int n=150000;
    struct Example {std::string name;std::vector<std::string> args;};
    const std::vector<Example> cases={
       {"C2X",{"abcdefg"}},
       {"BITXOR",{"abcdefghijklmnop","ABCDEFGHIJKL"}},
       {"LASTPOS",{"bc","abcabcabcabcabcabc","18","15"}},
       {"POS",{"bc","abcabcabcabcabcabc","2","15"}},
       {"WORDS",{"a  b   c  d  e"}},
       {"LEFT",{"abc","10","."}}
    };
    volatile std::uint64_t checksum=0;
    for(const auto &t:cases){
        rxbif::Context c;std::vector<rx::Value> args;
        for(const auto &s:t.args)args.push_back(rx::Value::string(s));
        for(int i=0;i<1000;i++)(void)rxbif::invoke(t.name,args,c);
        auto start=std::chrono::steady_clock::now();
        for(int i=0;i<n;i++){
            auto v=rxbif::invoke(t.name,args,c);
            checksum=checksum+v.bytes.size();
        }
        auto duration=std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count();
        std::cout<<t.name<<"\t"<<n<<"\t"<<(duration*1e9/n)<<"\t"<<static_cast<long long>(n/duration)<<"\n";
    }
    std::cerr<<"checksum="<<checksum<<"\n";
}
