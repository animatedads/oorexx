// Native dispatch boundary qualification. This is NOT an ooRexx class compiler
// test: class syntax is not supported in the Rexx parser yet. It proves the
// native ABI retains independent, left-object operator message dispatch.
#include "minirexx_runtime.hpp"
#include <memory>
#include <stdexcept>
#include <string>

struct LeftObject : rx::ObjectDispatch {
    int equalCalls = 0;
    int notEqualCalls = 0;
    int strictEqualCalls = 0;
    int addCalls = 0;
    int unaryCalls = 0;
    rx::Value sendBinary(const std::string &selector, const rx::Value &rhs) override {
        if (rhs.isObject() || rhs.bytes != "operand")
            throw std::runtime_error("right argument lost");
        if (selector == "=") { ++equalCalls; return rx::fromInteger(1); }
        if (selector == "\\=") { ++notEqualCalls; return rx::fromInteger(1); }
        if (selector == "==") { ++strictEqualCalls; return rx::fromInteger(0); }
        if (selector == "+") { ++addCalls; return rx::Value::string("custom plus"); }
        throw std::runtime_error("unknown custom binary selector: " + selector);
    }
    rx::Value sendUnary(const std::string &selector) override {
        if (selector != "-") throw std::runtime_error("wrong unary selector");
        ++unaryCalls;
        return rx::Value::string("custom minus");
    }
};
int main() {
    auto object = std::make_shared<LeftObject>();
    rx::Value lhs = rx::Value::fromObject(object);
    const auto rhs = rx::Value::string("operand");
    if (rx::sendBinary(lhs, "=", rhs).bytes != "1") return 1;
    // Equality and inequality methods deliberately BOTH return true, proving
    // the runtime does not implement \\= as ! (=).
    if (rx::sendBinary(lhs, "\\=", rhs).bytes != "1") return 2;
    if (rx::sendBinary(lhs, "==", rhs).bytes != "0") return 3;
    if (rx::sendBinary(lhs, "+", rhs).bytes != "custom plus") return 4;
    if (rx::sendUnary("-", lhs).bytes != "custom minus") return 5;
    if (object->equalCalls != 1 || object->notEqualCalls != 1 ||
        object->strictEqualCalls != 1 || object->addCalls != 1 || object->unaryCalls != 1) return 6;
    // Right-operand objects must never be compared as empty primitive strings.
    try {
        (void)rx::sendBinary(rhs, "=", lhs);
        return 7;
    } catch (const std::runtime_error &) { }
    return 0;
}
