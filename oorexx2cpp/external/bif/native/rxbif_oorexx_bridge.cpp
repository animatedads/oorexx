// Optional OO Rexx public API interop; never link into interpreter-free builds.
#include "rxbif_oorexx_bridge.hpp"
#include <oorexxapi.h>
#include <stdexcept>
#include <unordered_set>
namespace rxbif_breadth {
namespace {
const std::unordered_set<std::string> isolated = {
    "C2D","TRUNC","X2D","D2X","D2C","TRANSLATE","VERIFY","DATATYPE",
    "SIGN","FORMAT","MAX","MIN","XRANGE","USERID","ERRORTEXT","QUALIFY"
};
}
struct IsolatedOoRexx::Impl {
    RexxInstance* instance = nullptr;
    RexxThreadContext* thread = nullptr;
    std::string program;
    explicit Impl(std::string p) : program(std::move(p)) {
        if (!RexxCreateInterpreter(&instance,&thread,nullptr) || !instance || !thread)
            throw std::runtime_error("RexxCreateInterpreter failed");
    }
    ~Impl() { if (instance) instance->Terminate(); }
};
IsolatedOoRexx::IsolatedOoRexx(std::string path):impl(new Impl(std::move(path))) {}
IsolatedOoRexx::~IsolatedOoRexx()=default;
rx::Value IsolatedOoRexx::call(const std::string& name,const std::vector<Slot>& args,
                               const NumericContext& numeric) {
    validateNumericContext(numeric);
    if (isolated.count(name)==0) throw std::runtime_error("BIF " + name + " requires live activation chainback");
    auto* c=impl->thread;
    RexxArrayObject array=c->NewArray(args.size()+4);
    // Headers are fixed numeric strings / a closed enum, never user source.
    const std::string digits=std::to_string(numeric.digits);
    const std::string fuzz=std::to_string(numeric.fuzz);
    const std::string form=numeric.form == NumericForm::Engineering ? "ENGINEERING" : "SCIENTIFIC";
    c->ArrayPut(array,c->NewString(digits.data(),digits.size()),1);
    c->ArrayPut(array,c->NewString(fuzz.data(),fuzz.size()),2);
    c->ArrayPut(array,c->NewString(form.data(),form.size()),3);
    RexxStringObject id=c->NewString(name.data(),name.size());
    c->ArrayPut(array,id,4);
    for(std::size_t k=0;k<args.size();++k) {
        if (!args[k]) continue; // preserve omitted middle arguments as holes
        if(args[k]->isObject()) throw std::runtime_error("object BIF arguments require live activation");
        const auto& bytes=args[k]->bytes;
        RexxStringObject str=c->NewString(bytes.data(),bytes.size());
        c->ArrayPut(array,str,k+5);
    }
    RexxObjectPtr raw=c->CallProgram(impl->program.c_str(),array);
    if (!raw || c->CheckCondition()) {
        if (c->CheckCondition()) {c->DisplayCondition(); c->ClearCondition();}
        throw std::runtime_error("ooRexx detached BIF chainback failed: " + name);
    }
    RexxStringObject result=c->ObjectToString(raw);
    if (!result || c->CheckCondition()) {
        if (c->CheckCondition()) c->ClearCondition();
        throw std::runtime_error("ooRexx result is not string convertible: " + name);
    }
    const std::string bytes(c->StringData(result),c->StringLength(result));
    return rx::Value::string(bytes);
}
} // namespace rxbif_breadth
