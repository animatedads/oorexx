// drv_small: "digits fuzz a op b" lines (+ - *) -> native result (ERR code on a syntax condition).
#include "minirexx_runtime.hpp"
#include <iostream>
#include <sstream>
int main() {
    std::string line;
    while (std::getline(std::cin, line)) {
        std::istringstream in(line);
        int d, f; std::string a, op, b;
        in >> d >> f >> a >> op >> b;
        rx::ActivationNumeric n; n.digits = d; n.fuzz = f;
        const rx::Value x = rx::Value::string(a), y = rx::Value::string(b);
        try {
            rx::Value r = op == "+" ? rx::numericAdd(x, y, n) : op == "-" ? rx::numericSub(x, y, n) : rx::numericMul(x, y, n);
            std::cout << std::string(r.bytes) << "\n";
        } catch (const rx::SyntaxCondition &e) { std::cout << "ERR " << e.code << "\n"; }
        catch (const std::exception &e) { std::cout << "EXC " << e.what() << "\n"; }
    }
}
