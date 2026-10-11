#include "rxbif_x2d.hpp"
#include <iostream>
#include <string>
#include <cstdlib>
static int digit(char c){return (c>='0'&&c<='9')?c-'0':(c>='A'&&c<='F')?c-'A'+10:-1;}
static std::string decode(const std::string& x){std::string s;for(size_t i=0;i+1<x.size();i+=2){int a=digit(x[i]),b=digit(x[i+1]);if(a<0||b<0)abort();s.push_back(char(a*16+b));}return s;}
int main(int argc,char**argv){if(argc!=2)return 64;std::size_t precision=std::stoull(argv[1]);std::string l;
while(std::getline(std::cin,l)){
auto p=l.find('|');if(p==std::string::npos)abort();auto hex=decode(l.substr(0,p));auto w=l.substr(p+1);
bool specified=w!="-";size_t width=0;
if(specified){auto parsed=rxbif_x2d::parseWidth(decode(w));if(parsed.kind==rxbif_x2d::WidthKind::Invalid){std::cout<<"E\n";continue;}if(parsed.kind==rxbif_x2d::WidthKind::Unqualified){std::cout<<"U\n";continue;}width=parsed.value;}
auto r=rxbif_x2d::run(hex,specified,width,precision);
if(r.status==rxbif_x2d::Status::Value)std::cout<<"V"<<r.decimal<<"\n";else if(r.status==rxbif_x2d::Status::Unsupported)std::cout<<"U\n";else std::cout<<"E\n";
}}
