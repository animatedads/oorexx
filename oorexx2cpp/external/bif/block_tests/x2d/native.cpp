#include "rxbif_x2d.hpp"
#include <fstream>
#include <iostream>
#include <string>
using namespace rxbif_x2d;
int dig(char c){if(c>='0'&&c<='9')return c-'0';if(c>='A'&&c<='F')return c-'A'+10;throw 1;}
std::string decode(const std::string &h){std::string s;for(size_t i=0;i<h.size();i+=2)s+=char(dig(h[i])*16+dig(h[i+1]));return s;}
int main(int argc,char **argv){if(argc!=2)return 64;std::ifstream f(argv[1]);std::string line;
while(std::getline(f,line)){auto i=line.find('|'),j=line.find('|',i+1);auto input=decode(line.substr(0,i));auto n=line.substr(i+1,j-i-1);auto digits=std::stoul(line.substr(j+1));auto v=run(input,n!="-",n=="-"?0:std::stoul(n),digits);std::cout<<(v.status==Status::Value?"V"+v.decimal:v.status==Status::Unsupported?"U":"E")<<'\n';}}
