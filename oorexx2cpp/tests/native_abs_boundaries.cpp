// Fail closed outside the NUMERIC DIGITS 9 integer-only subset.
#include "minirexx_runtime.hpp"
#include <iostream>
#include <stdexcept>
int main() {
    auto abs = [](const std::string &s) {
        return rx::builtinValue("ABS", {rx::Value::string(s)}).bytes;
    };
    if (abs("-999999999") != "999999999") return 1;
    if (abs("-0003") != "3") return 2;
    for (const auto &s : {"1000000000", "-1000000000", "-9223372036854775808", "3.5"}) {
        try { (void)abs(s); return 3; }
        catch (const std::runtime_error &) { }
    }
    std::cout << "PASS ABS integer subset and explicit unsupported-value guard\n";
}
