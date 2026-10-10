// Native object-message ABI: no result, returned result, and cascade identity.
#include "minirexx_runtime.hpp"
#include <iostream>
struct CompiledThing final : rx::ObjectDispatch {
    rx::MessageResult sendMessage(const std::string &selector,
                                  const std::vector<rx::Value> &args) override {
        if (selector == "NOTHING" || selector == "VALUE") {
            if (!args.empty()) throw std::runtime_error("unexpected argument");
            if (selector == "NOTHING") return std::nullopt;
            return rx::Value::string("word");
        }
        return ObjectDispatch::sendMessage(selector, args);
    }
    std::string display() const override { return "compiled-object"; }
};
int main() {
    rx::Variables vars;
    rx::Value obj = rx::Value::fromObject(std::make_shared<CompiledThing>());
    rx::set(vars, "RESULT", rx::Value::string("stale"));
    rx::messageInstruction(vars, obj, "NOTHING", {}, false);
    std::cout << "no-result " << rx::get(vars, "RESULT").bytes << '\n';
    rx::messageInstruction(vars, obj, "NOTHING", {}, true);
    std::cout << "cascade-equals " << rx::sendBinary(rx::get(vars, "RESULT"), "==", obj).bytes << '\n';
    rx::messageInstruction(vars, obj, "VALUE", {}, false);
    std::cout << "returned " << rx::get(vars, "RESULT").bytes << '\n';
    auto x = rx::messageValue(obj, "VALUE", {}, false);
    std::cout << "expression " << x.bytes << ' ' << rx::get(vars, "RESULT").bytes << '\n';
    rx::messageInstruction(vars, obj, "=", {obj}, false);
    std::cout << "object-quoted-equal " << rx::get(vars, "RESULT").bytes << '\n';
    rx::messageInstruction(vars, obj, "NOTHING", {}, false);
    std::cout << "cleared " << rx::get(vars, "RESULT").bytes << '\n';
    try {
        (void)rx::messageValue(obj, "NOTHING", {}, false);
        return 3;
    } catch (const std::runtime_error &) { std::cout << "expression-no-result ERROR\n"; }
    return 0;
}
