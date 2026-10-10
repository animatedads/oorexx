// Native comparator prototype against tests/oorexx_object_inheritance.rex.
// Class declarations are NOT yet accepted by the Rexx precompiler.
#include "minirexx_runtime.hpp"
#include <iostream>
#include <memory>
#include <string>

struct Bare : rx::ObjectDispatch { };  // All six inherited from .Object.
struct EqualsOnly : rx::ObjectDispatch {
    rx::Value sendBinary(const std::string &name, const rx::Value &rhs) override {
        if (name == "=") return rx::Value::string("1");
        return ObjectDispatch::sendBinary(name, rhs);
    }
};
static void say(const std::string &label, const rx::Value &value) {
    std::cout << label << value.bytes << '\n';
}
int main() {
    auto a = std::make_shared<Bare>();
    auto b = std::make_shared<Bare>();
    auto override = std::make_shared<EqualsOnly>();
    const auto va = rx::Value::fromObject(a);
    const auto vb = rx::Value::fromObject(b);
    const auto vc = rx::Value::fromObject(override);
    const auto cmp = [](const rx::Value &l, const std::string &op, const rx::Value &r) {
        return rx::sendBinary(l, op, r);
    };
    say("bare a = a: ", cmp(va, "=", va));
    say("bare a = b: ", cmp(va, "=", vb));
    say("bare a == a: ", cmp(va, "==", va));
    say("bare a == b: ", cmp(va, "==", vb));
    say("bare a \\= a: ", cmp(va, "\\=", va));
    say("bare a \\= b: ", cmp(va, "\\=", vb));
    say("bare a \\== b: ", cmp(va, "\\==", vb));
    say("bare a <> b: ", cmp(va, "<>", vb));
    say("bare a >< b: ", cmp(va, "><", vb));
    say("bare alias == a: ", cmp(va, "==", va));
    say("custom = b: ", cmp(vc, "=", vb));
    say("custom \\= b: ", cmp(vc, "\\=", vb));
    say("custom == b: ", cmp(vc, "==", vb));
    say("custom \\== b: ", cmp(vc, "\\==", vb));
    say("custom <> b: ", cmp(vc, "<>", vb));
}
