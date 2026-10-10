// ooRexx native typed routine callable from macrospace-hosted Rexx proxies.
// Demonstrates compiled C++ object -> interpreter proxy -> compiled callback.
#include "compiled_registry.hpp"
#include <oorexxapi.h>
#include <limits>
#include <cstdlib>
#include <cerrno>

namespace rx2cpp {
Registry &Registry::instance() { static Registry instance; return instance; }
std::string Registry::add(std::shared_ptr<CompiledObject> object) {
    if (!object) throw std::invalid_argument("null compiled object");
    std::lock_guard<std::mutex> hold(gate_);
    std::string token = "native-" + std::to_string(++next_);
    objects_.emplace(token, std::move(object));
    return token;
}
void Registry::remove(const std::string &token) {
    std::lock_guard<std::mutex> hold(gate_);
    objects_.erase(token);
}
std::shared_ptr<CompiledObject> Registry::find(const std::string &token) {
    std::lock_guard<std::mutex> hold(gate_);
    auto it = objects_.find(token);
    return it == objects_.end() ? nullptr : it->second;
}
std::string CompiledCounter::invoke(const std::string &selector, const std::string &text) {
    if (selector == "DECORATE") return "native:" + text;
    if (selector != "INCREMENT") throw std::runtime_error("unsupported native selector: " + selector);
    if (text.empty() || text.find_first_not_of("+-0123456789") != std::string::npos)
        throw std::invalid_argument("non-integer increment");
    errno = 0;
    char *end = nullptr;
    long amount = std::strtol(text.c_str(), &end, 10);
    if (errno == ERANGE || end == text.c_str() || *end != '\0')
        throw std::invalid_argument("increment out of native range");
    if ((amount > 0 && value_ > std::numeric_limits<long>::max() - amount) ||
        (amount < 0 && value_ < std::numeric_limits<long>::min() - amount))
        throw std::overflow_error("native counter overflow");
    value_ += amount;
    return std::to_string(value_);
}
}

// Values are passed explicitly as an ooRexx Array. At this stage only a
// scalar .String conversion is supported at the actual native method edge;
// incoming non-scalar ooRexx objects are not silently treated as native ones.
RexxRoutine3(RexxObjectPtr, NativeDispatch,
             CSTRING, token, CSTRING, selector, RexxArrayObject, arguments)
{
    auto object = rx2cpp::Registry::instance().find(token);
    if (!object) {
        context->InvalidRoutine();
        return NULLOBJECT;
    }
    // A one-argument scalar or zero-argument call is supported for generated
    // methods; legacy DECORATE is the explicit interpreter-object callback.
    // A missing argument is never coerced into an empty string.
    const std::string method(selector);
    const bool decorated = method == "DECORATE";
    const auto count = context->ArrayItems(arguments);
    if (count > (decorated ? 2u : 1u) || (decorated && count != 2u)) {
        context->InvalidRoutine();
        return NULLOBJECT;
    }
    RexxObjectPtr value = NULLOBJECT;
    if (count != 0u) {
        value = context->ArrayAt(arguments, 1);
        if (value == NULLOBJECT || !context->IsOfType(value, "String")) {
            context->InvalidRoutine();
            return NULLOBJECT;
        }
    }
    if (decorated) {
        auto formatter = context->ArrayAt(arguments, 2);
        if (formatter == NULLOBJECT || !context->HasMethod(formatter, "RENDER")) {
            context->InvalidRoutine();
            return NULLOBJECT;
        }
        value = context->SendMessage1(formatter, "RENDER", value);
        if (context->CheckCondition() || value == NULLOBJECT) return NULLOBJECT;
    }
    try {
        // Rexx .String is length-delimited; CSTRING conversion would silently
        // truncate embedded NUL bytes. Preserve the exact byte length both ways.
        std::string argument;
        if (count != 0u) {
            auto stringValue = context->ObjectToString(value);
            argument.assign(context->StringData(stringValue), context->StringLength(stringValue));
        }
        const std::string result = count == 0u ? object->invoke0(method)
            : object->invoke(method, argument);
        return context->NewString(result.data(), result.size());
    } catch (const std::exception &) {
        context->InvalidRoutine();
        return NULLOBJECT;
    }
}

static RexxRoutineEntry routines[] = {
    REXX_TYPED_ROUTINE(NativeDispatch, NativeDispatch),
    REXX_LAST_ROUTINE()
};
RexxPackageEntry Rx2CppBridge_package_entry = {
    STANDARD_PACKAGE_HEADER
    REXX_CURRENT_INTERPRETER_VERSION,
    "rx2cppbridge", "0.9.0-dev1", nullptr, nullptr, routines, nullptr
};
OOREXX_GET_PACKAGE(Rx2CppBridge);
