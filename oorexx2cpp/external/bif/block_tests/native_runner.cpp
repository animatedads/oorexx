#include "rxbif.hpp"
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <stdexcept>
static int digit(char c){if(c>='0'&&c<='9')return c-'0';if(c>='A'&&c<='F')return c-'A'+10;if(c>='a'&&c<='f')return c-'a'+10;throw std::runtime_error("bad hex");}
static std::string decode(const std::string &s){if(s.size()%2)throw std::runtime_error("bad len");std::string out;for(size_t i=0;i<s.size();i+=2)out+=static_cast<char>((digit(s[i])<<4)|digit(s[i+1]));return out;}
static std::string encode(const std::string &s){static const char*h="0123456789ABCDEF";std::string o;for(unsigned char c:s){o+=h[c>>4];o+=h[c&15];}return o;}
int main(int argc,char **argv){if(argc!=2)return 2;std::ifstream in(argv[1]);std::string line;while(std::getline(in,line)){
  std::vector<std::string> cols;size_t st=0;for(size_t i=0;i<=line.size();i++){if(i==line.size()||line[i]=='\t'){cols.push_back(line.substr(st,i-st));st=i+1;}}
  if(cols.size()<3)continue;
  try{std::vector<rx::Value> args;for(size_t i=3;i<cols.size();i++)args.push_back(rx::Value::string(decode(cols[i])));
    rxbif::Context context;auto value=rxbif::invoke(cols[1],args,context);
    std::cout<<cols[0]<<":"<<encode(value.bytes.str())<<"\n";
  }catch(const std::exception&e){std::cout<<cols[0]<<":EXCEPTION:"<<e.what()<<"\n";}}
}
