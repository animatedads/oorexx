#include "rxbif_generated.hpp"
#include <iostream>
#include <stdexcept>
#include <vector>
namespace {
void test(bool ok, const char *message) {
    if (!ok) throw std::runtime_error(message);
}
std::vector<rx::Value> args(std::initializer_list<const char *> values) {
    std::vector<rx::Value> a;
    for (auto s : values) a.push_back(rx::Value::string(s));
    return a;
}
}
int main() {
    rxbif::Context ctx;
    using namespace rxbif_generated;
    test(BIF_REVERSE(args({"ABC xyz"}),ctx).bytes == "zyx CBA", "inline REVERSE");
    test(BIF_REVERSE(args({"ab"}),ctx).bytes == rxbif::invoke("REVERSE",args({"ab"}),ctx).bytes, "reverse native parity");
    test(BIF_WORDS(args({"  Alpha \tBeta  Gamma  "}),ctx).bytes == "3", "inline WORDS");
    test(BIF_WORDS(args({"a b c"}),ctx).bytes == rxbif::invoke("WORDS",args({"a b c"}),ctx).bytes, "words native parity");
    test(BIF_CENTER(args({"ab","6","-"}),ctx).bytes == "--ab--", "CENTER native boundary");
    test(BIF_TIME(args({"N","12:34:56","N"}),ctx).bytes == "12:34:56", "TIME native boundary");
    test(BIF_TIME(args({"H","12:34:56","N"}),ctx).bytes == "12", "TIME hour conversion");
    bool caught=false;
    try { (void) BIF_REVERSE(args({}),ctx); } catch (const std::runtime_error&) { caught=true; }
    test(caught, "inline arity gate");
    caught=false;
    try { (void) BIF_TIME(args({"R","12:34:56","N"}),ctx); } catch (const std::runtime_error&) { caught=true; }
    test(caught, "unqualified elapsed clock must fail closed");
    test(BIF_C2X(args({"AZ"}),ctx).bytes == "415A", "inline C2X upper hex");
    test(BIF_C2X(args({""}),ctx).bytes == "", "inline C2X empty");
    std::vector<rx::Value> binary{rx::Value::string(std::string("a\0z", 3))};
    test(BIF_C2X(binary,ctx).bytes == "61007A", "inline C2X embedded NUL");
    test(BIF_C2X(args({"hello"}),ctx).bytes == rxbif::invoke("C2X",args({"hello"}),ctx).bytes, "C2X native parity");
    test(BIF_COPIES(args({"ab","3"}),ctx).bytes == "ababab", "inline COPIES");
    test(BIF_COPIES(args({"ab","0"}),ctx).bytes == "", "inline COPIES zero");
    test(BIF_COPIES(args({"xyz","2"}),ctx).bytes == rxbif::invoke("COPIES",args({"xyz","2"}),ctx).bytes, "COPIES native parity");
    caught=false;
    try { (void) BIF_COPIES(args({"x","-1"}),ctx); } catch (const std::runtime_error&) { caught=true; }
    test(caught, "inline COPIES negative fails closed");
    test(BIF_X2C(args({"4142"}),ctx).bytes == "AB", "X2C helper boundary");
    test(BIF_B2X(args({"101"}),ctx).bytes == "5", "B2X three bits left padded");
    test(BIF_B2X(args({"10101111"}),ctx).bytes == "AF", "B2X byte bits");
    test(BIF_B2X(args({""}),ctx).bytes == "", "B2X empty");
    test(BIF_B2X(args({"10101111"}),ctx).bytes == rxbif::invoke("B2X",args({"10101111"}),ctx).bytes, "B2X native parity");
    test(BIF_X2B(args({"Fa"}),ctx).bytes == "11111010", "X2B mixed case");
    test(BIF_X2B(args({""}),ctx).bytes == "", "X2B empty");
    test(BIF_X2B(args({"A"}),ctx).bytes == "1010", "X2B single nibble");
    test(BIF_X2B(args({"f0"}),ctx).bytes == rxbif::invoke("X2B",args({"f0"}),ctx).bytes, "X2B native parity");
    for (const auto& n : {"BITAND", "BITOR", "BITXOR"}) {
        std::vector<rx::Value> single = args({"ABC"});
        rx::Value inlineAnswer = std::string(n)=="BITAND" ? BIF_BITAND(single,ctx) :
            std::string(n)=="BITOR" ? BIF_BITOR(single,ctx) : BIF_BITXOR(single,ctx);
        test(inlineAnswer.bytes == "ABC", "bit identity");
        std::vector<rx::Value> binary = {rx::Value::string(std::string("\xF0",1)),rx::Value::string(std::string("\x0F",1))};
        rx::Value ans = std::string(n)=="BITAND" ? BIF_BITAND(binary,ctx) :
            std::string(n)=="BITOR" ? BIF_BITOR(binary,ctx) : BIF_BITXOR(binary,ctx);
        test(ans.bytes == rxbif::invoke(n,binary,ctx).bytes,"bit native parity");
        test(ans.bytes == (std::string(n)=="BITAND" ? std::string("\0",1):std::string("\xFF",1)), "bit byte truth table");
    }
    caught=false;
    try { (void)BIF_X2B(args({"G0"}),ctx); } catch (const std::runtime_error&) { caught=true; }
    test(caught, "bad hex fails closed");
    caught=false;
    try { (void)BIF_B2X(args({"0002"}),ctx); } catch (const std::runtime_error&) { caught=true; }
    test(caught, "bad bit fails closed");
    std::cout << "PASS 37 generated-CPP cases (9 inline, 3 helper wrappers)\n";
}
