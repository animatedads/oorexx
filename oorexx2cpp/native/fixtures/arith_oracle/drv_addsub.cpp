// drv: reads "digits a op b" lines, prints the native result of a op b under NUMERIC DIGITS digits.
#include "minirexx_runtime.hpp"
#include <iostream>
#include <sstream>
int main() {
    std::string line;
    while (std::getline(std::cin, line)) {
        std::istringstream in(line);
        int d; std::string a, op, b;
        in >> d >> a >> op >> b;
        rx::ActivationNumeric n; n.digits = d; n.fuzz = 0;
        try {
            rx::Value r = op == "+" ? rx::numericAdd(rx::Value::string(a), rx::Value::string(b), n)
                                    : rx::numericSub(rx::Value::string(a), rx::Value::string(b), n);
            std::cout << std::string(r.bytes) << "\n";
        } catch (const std::exception &e) { std::cout << "ERR " << e.what() << "\n"; }
    }
}
