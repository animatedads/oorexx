// Limited build-only C++ model. NOT an ooRexx semantic oracle.
// It compiles the *production* rx_native_nine.hpp class implementations.
#include <string>
#include <vector>
#include <memory>
#include <optional>
#include <stdexcept>
#include <utility>
#include <cctype>
#include <cstddef>
namespace rx {
struct Text : std::string {
 using std::string::string;
 const std::string &str()const{return *this;}
 Text&operator=(const std::string &v){std::string::operator=(v);return *this;}
};
struct ObjectDispatch;
struct Value {
 Text bytes; std::shared_ptr<ObjectDispatch> object;
 Value()=default;
 explicit Value(std::string s):bytes(s.data(),s.size()){}
 explicit Value(std::shared_ptr<ObjectDispatch> v):object(std::move(v)){}
 static Value string(const std::string &s){return Value(s);}
 static Value fromObject(std::shared_ptr<ObjectDispatch> v){return Value(std::move(v));}
 bool isObject()const{return (bool)object;}
};
using MessageResult=std::optional<Value>;
struct ObjectDispatch {
 virtual MessageResult sendMessage(const std::string &,const std::vector<Value>&){return std::nullopt;}
 virtual Value sendBinary(const std::string &,const Value &){return Value::string("0");}
 virtual Value sendUnary(const std::string&){return Value::string("0");}
 virtual std::string display() const{return "X";}
 virtual ~ObjectDispatch()=default;
};
struct NativeRefBase:ObjectDispatch {virtual void *materialize()=0;};
struct EnvObject:ObjectDispatch {void *handle=nullptr; explicit EnvObject(void*h=nullptr):handle(h){}};
struct NativeArray:ObjectDispatch {
 static bool omitted(const Value&){return false;}
 std::vector<std::optional<Value>> slots;
 std::size_t count=0;
 std::optional<Value> real;
 std::optional<std::vector<Value>> snapshotItems(){
   if(real) return std::nullopt;
   std::vector<Value> out;
   for(const auto &s:slots) if(s) out.push_back(*s);
   return out;
 }
};
inline Value nil(){return Value::fromObject(std::make_shared<EnvObject>());}
inline Value envClass(const std::string &){return Value::fromObject(std::make_shared<EnvObject>());}
}
#include "../../include/rx_native_nine.hpp"
