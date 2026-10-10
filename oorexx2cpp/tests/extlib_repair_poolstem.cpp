/* The repaired rx2cpp_extlib v0.1b uses separate symbol and literal stem
 * hooks. Verify they resolve through the same PROCEDURE/EXPOSE owner without
 * treating a literal stem-element tail as a variable reference. */
#include "minirexx_runtime.hpp"
#include "rx2cpp_extlib.hpp"
#include <cassert>
#include <iostream>
#include <optional>
#include <string>

int main() {
    rx::Variables parent;
    rx::set(parent, "S.BAR", rx::Value::string("bar-before"));
    rx::Variables child(parent, {"S."});
    rx::set(child, "I", rx::Value::string("BAR"));
    rxext::Host host;
    // Symbol hooks perform Rexx variable-tail substitution in this activation.
    host.varSet = [&](const std::string& name, const std::string& value) {
        rx::setSymbol(child, name, rx::Value::string(value));
    };
    host.varGet = [&](const std::string& name) -> std::optional<std::string> {
        const rx::Value value = rx::getSymbol(child, name);
        return value.bytes;
    };
    host.varDrop = [&](const std::string& name) {
        const auto resolved = rx::compoundSymbol(name) ? rx::compoundKey(child, name) : name;
        rx::drop(child, resolved);
    };
    // Literal tail hooks deliberately bypass substitution of I -> BAR.
    host.tailSet = [&](const std::string& stem, const std::string& tail,
                       const std::string& value) {
        rx::set(child, stem + tail, rx::Value::string(value));
    };
    host.tailGet = [&](const std::string& stem, const std::string& tail)
        -> std::optional<std::string> {
        const rx::Value* v = rx::lookup(child, stem + tail);
        return v ? std::optional<std::string>(v->bytes) : std::nullopt;
    };
    host.tailDrop = [&](const std::string& stem, const std::string& tail) {
        rx::drop(child, stem + tail);
    };
    host.varSet("S.I", "symbol-value");
    assert(rx::get(parent, "S.BAR").bytes == "symbol-value");
    auto* stem = host.poolStem("S.");
    stem->set("I", "literal-value");
    assert(stem->get("I").value() == "literal-value");
    assert(rx::get(parent, "S.I").bytes == "literal-value");
    assert(rx::get(parent, "S.BAR").bytes == "symbol-value");
    stem->drop("I");
    assert(!rx::lookup(parent,"S.I"));
    assert(rx::get(parent,"S.BAR").bytes == "symbol-value");
    std::cout << "PASS repaired extlib raw symbol vs literal stem-tail hooks\n";
}
