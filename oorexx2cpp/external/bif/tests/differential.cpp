#include "rxbif.hpp"
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
struct Case { const char *name; std::vector<std::string> args; };
const std::vector<Case> cases={
    {"DATE",{"I","2024-02-29","I"}}, {"DATE",{"N","2024-02-29","I"}},
    {"DATE",{"S","2024-02-29","I"}}, {"DATE",{"B","2024-02-29","I"}},
    {"DATE",{"D","2024-02-29","I"}}, {"DATE",{"E","2024-02-29","I"}},
    {"DATE",{"U","2024-02-29","I"}}, {"DATE",{"O","2024-02-29","I"}},
    {"DATE",{"L","2024-02-29","I"}}, {"DATE",{"W","2024-02-29","I"}},
    {"DATE",{"M","2024-02-29","I"}}, {"DATE",{"I","738944","B"}},
    {"TIME",{"N","13:02:03","N"}}, {"TIME",{"C","13:02:03","N"}},
    {"TIME",{"L","13:02:03","N"}}, {"TIME",{"H","13:02:03","N"}},
    {"TIME",{"M","13:02:03","N"}}, {"TIME",{"S","13:02:03","N"}},
    {"TIME",{"N","123","S"}}, {"TIME",{"N","13","H"}},
    {"TIME",{"N","82","M"}}, {"TIME",{"L","01:02:03.123456","L"}},
    {"REVERSE",{"Abc de"}}, {"REVERSE",{""}},
    {"COPIES",{"ab","3"}}, {"COPIES",{"X","0"}},
    {"SUBSTR",{"abcdef","3"}}, {"SUBSTR",{"abcdef","3","2"}},
    {"SUBSTR",{"abcdef","8","3","."}}, {"SUBSTR",{"a","1","4","-"}},
    {"LEFT",{"abcdef","3"}}, {"LEFT",{"abc","6","-"}},
    {"RIGHT",{"abcdef","3"}}, {"RIGHT",{"abc","6","-"}},
    {"CENTER",{"abc","6","-"}}, {"CENTRE",{"abc","5","-"}},
    {"CENTER",{"abcdef","3"}}, {"CENTER",{"abcdef","4"}},
    {"STRIP",{"   abc  "}}, {"STRIP",{"..abc..","L","."}},
    {"STRIP",{"..abc..","T","."}},
    {"SPACE",{"   a   b  "}}, {"SPACE",{" a  b ","2","-"}},
    {"WORDS",{"a   b  c"}}, {"WORDS",{""}},
    {"WORD",{" a  b c","2"}}, {"WORD",{"a b","3"}},
    {"WORDINDEX",{" a  b c","2"}}, {"WORDLENGTH",{"abc def","2"}},
    {"SUBWORD",{" a  b   c d ","2"}}, {"SUBWORD",{" a  b   c d ","2","2"}},
    {"DELWORD",{" a  b   c d ","2"}}, {"DELWORD",{" a  b   c d ","2","1"}},
    {"WORDPOS",{"b c","a b c d"}}, {"WORDPOS",{"a","x a b a","3"}},
    {"POS",{"bc","abcabc"}}, {"POS",{"bc","abcabc","4"}},
    {"POS",{"","abc"}}, {"LASTPOS",{"bc","abcabc"}},
    {"LASTPOS",{"bc","abcabc","4"}}, {"LASTPOS",{"","abc"}},
    {"ABBREV",{"alphabet","alph"}}, {"ABBREV",{"alphabet","a","2"}},
    {"COMPARE",{"abc","abc"}}, {"COMPARE",{"abc","abX"}},
    {"COMPARE",{"abc","abc ","."}},
    {"COUNTSTR",{"ab","abababa"}}, {"CHANGESTR",{"ab","abababa","X"}},
    {"CHANGESTR",{"ab","abababa","X","2"}},
    {"DELSTR",{"abcdef","2"}}, {"DELSTR",{"abcdef","2","3"}},
    {"DELSTR",{"abcdef"}},
    {"INSERT",{"xy","abc"}}, {"INSERT",{"xy","abc","2"}},
    {"INSERT",{"xy","abc","7","5","."}},
    {"OVERLAY",{"xy","abc"}}, {"OVERLAY",{"xy","abc","2"}},
    {"OVERLAY",{"xy","abc","6","5","."}},
    {"UPPER",{"abcDEF"}}, {"LOWER",{"ABcDEF"}},
    {"UPPER",{"abcdef","3","2"}}, {"LOWER",{"ABcdEF","3","2"}},
    {"C2X",{"hi"}}, {"C2X",{""}},
    {"B2X",{""}}, {"B2X",{"1"}}, {"B2X",{"101"}},
    {"B2X",{"11110000"}}, {"B2X",{"00000000"}},
    {"X2B",{""}}, {"X2B",{"A"}}, {"X2B",{"fA"}}, {"X2B",{"09"}},
    {"BITAND",{"abc"}}, {"BITOR",{"abc"}}, {"BITXOR",{"abc"}},
    {"BITAND",{"abc","A"}}, {"BITOR",{"abc","A"}}, {"BITXOR",{"abc","A"}},
    {"BITAND",{"abc","A","-"}}, {"BITOR",{"abc","A","-"}}, {"BITXOR",{"abc","A","-"}},
    {"BITAND",{"","abc"}}, {"BITOR",{"","abc"}}, {"BITXOR",{"","abc"}},
    {"BITAND",{"abc",""}}, {"BITOR",{"abc",""}}, {"BITXOR",{"abc",""}},
    {"X2C",{"4869"}}, {"X2C",{"41 42"}}
};
static std::string quot(const std::string &s){std::string q="'";for(char c:s){q+=c;if(c=='\'')q+=c;}return q+"'";}
static std::string hex(const std::string &s){const char *h="0123456789ABCDEF";std::string r;for(unsigned char c:s){r+=h[c>>4];r+=h[c&15];}return r;}
int main(int argc,char **argv){
    if(argc==2&&std::string(argv[1])=="--rexx"){
        for(size_t i=0;i<cases.size();i++){
            const auto &t=cases[i];std::cout<<"say '"<<i<<":' || c2x("<<t.name<<"(";
            for(size_t j=0;j<t.args.size();j++){if(j)std::cout<<",";std::cout<<quot(t.args[j]);}
            std::cout<<"))\n";
        }return 0;
    }
    rxbif::Context ctx;
    for(size_t i=0;i<cases.size();i++){
        const auto &t=cases[i];std::vector<rx::Value> vs;
        for(const auto &a:t.args)vs.emplace_back(rx::Value::string(a));
        try{auto ans=rxbif::invoke(t.name,vs,ctx);std::cout<<i<<":"<<hex(ans.bytes)<<"\n";}
        catch(const std::exception &e){std::cerr<<"CASE "<<i<<" "<<t.name<<": "<<e.what()<<"\n";return 1;}
    }
}
