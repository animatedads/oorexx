#include "rxbif_live_call.hpp"
#include <stdexcept>
#include <utility>
#include <algorithm>

namespace rxbif_live {
CallScope::CallScope(RexxCallContext *caller)
    : caller_(caller),
      original_(caller != nullptr ? caller->GetInterpreterInstance() : nullptr),
      native_(),
      bif_(native_, [this](const std::string& name,
                          const std::vector<rxbif_breadth::Slot>& arguments,
                          const rxbif_breadth::NumericContext& numeric) {
          // A changed/stale snapshot must NEVER be applied to a live activation.
          validate();
          const rxbif_breadth::NumericContext now {
              static_cast<std::size_t>(caller_->GetContextDigits()),
              static_cast<std::size_t>(caller_->GetContextFuzz()),
              caller_->GetContextForm() ? rxbif_breadth::NumericForm::Engineering
                                        : rxbif_breadth::NumericForm::Scientific
          };
          if (now.digits != numeric.digits || now.fuzz != numeric.fuzz || now.form != numeric.form)
              throw std::runtime_error("BIF: NUMERIC context changed during delegation");
          return execute(name, arguments, numeric);
      }, std::nullopt, [this]() -> rxbif_breadth::NumericContext {
          validate();
          return {
              static_cast<std::size_t>(caller_->GetContextDigits()),
              static_cast<std::size_t>(caller_->GetContextFuzz()),
              caller_->GetContextForm() ? rxbif_breadth::NumericForm::Engineering
                                        : rxbif_breadth::NumericForm::Scientific
          };
      }) {
    validate();
    bif_.preferChainback = true; // even native BIFs must be caller-scoped in this adapter
}

void CallScope::validate() const {
    if (!caller_ || !original_ || !caller_->threadContext) {
        throw std::runtime_error("BIF: missing live ooRexx routine activation");
    }
    if (caller_->GetInterpreterInstance() != original_ ||
        caller_->threadContext->GetInterpreterInstance() != original_) {
        throw std::runtime_error("BIF: thread/instance mismatch in live routine activation");
    }
}

rx::Value CallScope::invoke(const std::string& name) {
    validate();
    return rxbif_breadth::invoke(name, {}, bif_);
}

rx::Value CallScope::invoke(const std::string& name, const std::vector<rxbif_breadth::Slot>& args) {
    validate();
    return rxbif_breadth::invoke(name, args, bif_);
}

rx::Value CallScope::execute(const std::string& name,
                            const std::vector<rxbif_breadth::Slot>& arguments,
                            const rxbif_breadth::NumericContext& snapshot) {
    validate();
    // Scopeless BIFs are safe to run as a new routine *in the same instance*
    // only when the caller's NUMERIC context is explicitly reproduced.
    // Host state BIFs (ARG, VALUE, TRACE, streams, etc.) remain rejected.
    if (name == "FORMAT" || rxbif_breadth::catalog().end() !=
        std::find_if(rxbif_breadth::catalog().begin(), rxbif_breadth::catalog().end(),
                     [&name](const rxbif_breadth::Spec& spec) {
                         return name == spec.name && std::string(spec.mode) == "ISOLATED_REXX";
                     })) {
        if (name == "FORMAT" && (arguments.empty() || !arguments[0]))
            throw std::runtime_error("BIF FORMAT: missing required number or incorrect count");
        const auto& numeric = snapshot;
        rxbif_breadth::validateNumericContext(numeric);
        // Only a source-pinned, catalogued built-in name enters the program.
        // Supplied argument values travel as Rexx arguments, NEVER source text.
        std::string body = "numeric digits " + std::to_string(numeric.digits) + "\n";
        body += "numeric fuzz " + std::to_string(numeric.fuzz) + "\n";
        body += std::string("numeric form ") +
                (numeric.form == rxbif_breadth::NumericForm::Engineering ? "ENGINEERING" : "SCIENTIFIC") + "\n";
        body += "return " + name + "(";
        RexxArrayObject values = caller_->NewArray(arguments.size());
        for (std::size_t i = 0; i < arguments.size(); ++i) {
            if (i) body += ',';
            if (!arguments[i]) continue;
            if (arguments[i]->isObject())
                throw std::runtime_error("BIF " + name + ": object marshalling not qualified");
            caller_->ArrayPut(values, caller_->NewString(arguments[i]->bytes.data(), arguments[i]->bytes.size()),i+1);
            body += "ARG(" + std::to_string(i+1) + ")";
        }
        body += ")\n";
        RexxRoutineObject trampoline = caller_->NewRoutine("rx2cpp_numeric_bif",body.data(),body.size());
        if (trampoline == NULLOBJECT || caller_->CheckCondition())
            throw std::runtime_error("BIF " + name + ": cannot compile numeric-context trampoline");
        RexxObjectPtr raw = caller_->CallRoutine(trampoline,values);
        if (raw == NULLOBJECT || caller_->CheckCondition())
            throw std::runtime_error("BIF " + name + ": interpreter rejected arguments");
        RexxStringObject result = caller_->ObjectToString(raw);
        if (result == NULLOBJECT || caller_->CheckCondition())
            throw std::runtime_error("BIF " + name + ": non-scalar result");
        return rx::Value::string(std::string(caller_->StringData(result),caller_->StringLength(result)));
    }
    if (!arguments.empty()) throw std::runtime_error("BIF live context probe forbids arguments");
    if (name == "DIGITS") return rx::Value::string(std::to_string(caller_->GetContextDigits()));
    if (name == "FUZZ") return rx::Value::string(std::to_string(caller_->GetContextFuzz()));
    if (name == "FORM") return rx::Value::string(caller_->GetContextForm() ? "ENGINEERING" : "SCIENTIFIC");
    // Even though other BIFs have catalogue routes, this borrowed native routine
    // has not been given the original compiled frame's variables, receiver,
    // trace/condition state, stream registry, queue or argument list.
    throw std::runtime_error("BIF " + name + ": no qualified live activation adapter");
}

RexxObjectPtr asRexxScalar(RexxCallContext *caller, const rx::Value& value) {
    if (caller == nullptr || value.isObject()) {
        throw std::runtime_error("BIF: live ooRexx object marshalling not qualified");
    }
    return caller->NewString(value.bytes.data(), value.bytes.size());
}
} // namespace rxbif_live
