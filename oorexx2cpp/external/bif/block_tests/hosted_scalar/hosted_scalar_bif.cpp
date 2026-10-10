// BIF-side adapter qualification against the checked HostedSession public API.
// An independent hosted Rexx routine is not the original compiled activation.
#include "rxbif_breadth.hpp"
#include "HostedSession.hpp"
#include <cassert>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

class HostedScalarRoute final {
public:
    rx::Value invoke(const std::string& name,
                     const std::vector<rxbif_breadth::Slot>& args,
                     const rxbif_breadth::NumericContext& numeric) {
        rxbif_breadth::validateNumericContext(numeric);
        // Explicitly qualify the return types of only these three BIFs.
        // Never coerce an arbitrary hosted object into an rx::Value string.
        if ((name != "ERRORTEXT" && name != "X2C" && name != "DATATYPE") ||
            args.size() != (name == "DATATYPE" ? 2U : 1U) ||
            !args[0] || args[0]->isObject() ||
            (name == "DATATYPE" && (!args[1] || args[1]->isObject())))
            throw std::runtime_error("hosted BIF: unqualified operation or argument");
        const std::string source =
            "numeric digits " + std::to_string(numeric.digits) + "\n" +
            "numeric fuzz " + std::to_string(numeric.fuzz) + "\n" +
            (numeric.form == rxbif_breadth::NumericForm::Scientific
              ? "numeric form scientific\n" : "numeric form engineering\n") +
            "use arg value, option\nreturn " + name +
            (name == "DATATYPE" ? "(value,option)\n" : "(value)\n");
        auto arg = hosted_.string(args[0]->bytes);
        std::optional<rx2cpp::hosted::Session::Object> response;
        if (name == "DATATYPE") {
            auto option = hosted_.string(args[1]->bytes);
            response = hosted_.runRoutineSource(source, {arg,option});
        } else {
            response = hosted_.runRoutineSource(source, {arg});
        }
        if (!response) throw std::runtime_error("hosted BIF: no result object");
        // Names above are specifically admitted and return scalar String or
        // Boolean. Session::Object retains identity until we explicitly
        // convert the scalar result at this documented BIF boundary.
        return rx::Value::string(response->asString());
    }
private:
    rx2cpp::hosted::Session hosted_;
};

int main() {
    HostedScalarRoute host;
    rxbif::Context native;
    int fallbackCalls=0, numericReads=0;
    std::size_t liveDigits=9;
    rxbif_breadth::Context routing(native,
      [&](const std::string& n,const std::vector<rxbif_breadth::Slot>& a,
          const rxbif_breadth::NumericContext& numeric) {
          ++fallbackCalls;
          return host.invoke(n,a,numeric);
      }, {}, [&] {
          ++numericReads;
          return rxbif_breadth::NumericContext{liveDigits,0,rxbif_breadth::NumericForm::Scientific};
      });
    const auto one=[&](const std::string& n, const std::string& a) {
        return rxbif_breadth::invoke(n,{rx::Value::string(a)},routing);
    };
    assert(one("SIGN","-12345").bytes=="-1");
    assert(fallbackCalls==0 && numericReads==0);
    const auto msg=one("ERRORTEXT","40").bytes;
    assert(!msg.empty() && fallbackCalls==1 && numericReads==1);
    routing.preferChainback=true;
    const auto binary=one("X2C","0001FF41").bytes;
    assert(binary==std::string("\0\x01\xff" "A",4) && fallbackCalls==2);
    bool error=false;
    try { (void)one("ERRORTEXT","bad"); }
    catch (const rx2cpp::hosted::Condition& e) { error=e.code!=0; }
    assert(error && fallbackCalls==3);
    assert(one("ERRORTEXT","40").bytes==msg && fallbackCalls==4);
    routing.preferChainback=false;
    auto datatype=[&] {return rxbif_breadth::invoke("DATATYPE", {
        rx::Value::string("1.5"),rx::Value::string("W")},routing).bytes;};
    liveDigits=1;
    assert(datatype()=="1" && fallbackCalls==5);
    liveDigits=2;
    assert(datatype()=="0" && fallbackCalls==6);
    bool rejected=false;
    try { (void)rxbif_breadth::invoke("ARG",{},routing); }
    catch(const std::runtime_error& e) {rejected=std::string(e.what()).find("unqualified")!=std::string::npos;}
    assert(rejected && fallbackCalls==7);
    std::cout<<"PASS native SIGN, hosted scalar calls, binary, condition clear, live NUMERIC DIGITS, ARG rejection\n";
}
