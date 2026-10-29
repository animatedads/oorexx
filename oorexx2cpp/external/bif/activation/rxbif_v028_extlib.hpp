#pragma once
// Optional rx2cpp-extlib v0.1b companion; does not modify either upstream.
// ALWAYS call through TypedHostBridge::call() to refresh NUMERIC before each
// typed-routine call. Direct rxext::Host::call cannot enforce that boundary.
#include "rxbif_v028_activation.hpp"
#include "rx2cpp_extlib.hpp"
#include <optional>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace rxbif_v028 {
class TypedHostBridge final {
public:
    TypedHostBridge(rxext::Host& host, PoolSupplier owner)
        : host_(host), owner_(std::move(owner)) {
        if (!owner_) throw std::invalid_argument("rxext: activation pool supplier required");
        // Capture supplier by VALUE. Host owns the hooks. The supplier must
        // remain able to return a valid current activation while host is used.
        auto getPool = owner_;
        host_.varSet=[getPool](const std::string& raw,const std::string& s) {
            auto& vars = checked(getPool);
            const auto symbol=qualifiedSymbol(raw);
            rx::setSymbol(vars,symbol,rx::Value::string(s));
        };
        host_.varGet=[getPool](const std::string& raw)->std::optional<std::string> {
            auto& vars = checked(getPool);
            const auto symbol=qualifiedSymbol(raw);
            const std::string resolved=rx::compoundSymbol(symbol)?rx::compoundKey(vars,symbol):symbol;
            const rx::Value* value=rx::lookup(vars,resolved);
            // GetContextVariable returns NULL when unset. A stem default is
            // deliberately observable for an unresolved compound element.
            if (!value && rx::compoundSymbol(symbol)) {
                const auto stem=symbol.substr(0,symbol.find('.')+1);
                value=rx::lookup(vars,stem);
            }
            if (!value) return std::nullopt;
            return scalar(*value);
        };
        host_.varDrop=[getPool](const std::string& raw) {
            auto& vars=checked(getPool);
            const auto symbol=qualifiedSymbol(raw);
            rx::drop(vars,rx::compoundSymbol(symbol)?rx::compoundKey(vars,symbol):symbol);
        };
        host_.tailSet=[getPool](const std::string& stem,const std::string& tail,const std::string& s) {
            auto& vars=checked(getPool);
            rx::set(vars,stemKey(stem)+tail,rx::Value::string(s));
        };
        host_.tailGet=[getPool](const std::string& stem,const std::string& tail)->std::optional<std::string> {
            auto& vars=checked(getPool);
            const rx::Value* value=rx::lookup(vars,stemKey(stem)+tail);
            if (!value) return std::nullopt;
            return scalar(*value);
        };
        host_.tailDrop=[getPool](const std::string& stem,const std::string& tail) {
            auto& vars=checked(getPool);
            rx::drop(vars,stemKey(stem)+tail);
        };
    }
    TypedHostBridge(const TypedHostBridge&)=delete;
    TypedHostBridge& operator=(const TypedHostBridge&)=delete;

    std::optional<std::string> call(const std::string& name,
                                    const std::vector<rxext::Host::Arg>& args) {
        rx::Variables& vars=checked(owner_);
        const NumericContext num=rx::frameNumeric(vars);
        rxbif_breadth::validateNumericContext(num);
        host_.numeric.digits=num.digits;
        host_.numeric.fuzz=num.fuzz;
        host_.numeric.form=num.form==rxbif_breadth::NumericForm::Engineering?1:0;
        return host_.call(name,args);
    }
private:
    static rx::Variables& checked(const PoolSupplier& get) {
        rx::Variables* vars=get();
        if (!vars) throw std::runtime_error("rxext: original activation unavailable");
        return *vars;
    }
    static std::string qualifiedSymbol(const std::string& raw) {
        std::string out;
        bool literal=false;
        if (!rx::splitBifSymbol(raw,out,literal) || literal)
            throw std::runtime_error("rxext: invalid or nonassignable variable symbol");
        return out;
    }
    static std::string stemKey(const std::string& raw) {
        const auto symbol=qualifiedSymbol(raw);
        if (symbol.back()!='.')
            throw std::runtime_error("rxext: stem name must end with dot");
        return symbol;
    }
    static std::string scalar(const rx::Value& value) {
        if (value.isObject())
            throw std::runtime_error("rxext: object variable requires qualified object ABI");
        return value.bytes.str();
    }
    rxext::Host& host_;
    PoolSupplier owner_;
};
} // namespace rxbif_v028
