// Native executable bridge proof: execute a macrospace routine implementing
// a Rexx proxy, which calls back into a live compiled C++ object.
#include "compiled_registry.hpp"
#include "rexx_object_proxy.hpp"
#include <oorexxapi.h>
#include <rexx.h>
#include <rexxapidefs.h>
#include <unistd.h>
#include <memory>
#include <iostream>
#include <stdexcept>
#include <string>
#include <cstring>

extern RexxPackageEntry Rx2CppBridge_package_entry;

class Interpreter {
public:
    RexxInstance *instance = nullptr;
    RexxThreadContext *thread = nullptr;
    Interpreter() {
        if (!RexxCreateInterpreter(&instance, &thread, nullptr))
            throw std::runtime_error("RexxCreateInterpreter failed");
    }
    ~Interpreter() { if (instance) instance->Terminate(); }
    Interpreter(const Interpreter &) = delete;
    Interpreter &operator=(const Interpreter &) = delete;
};
class ScopedMacro {
    std::string name_;
    bool registered_ = false;
public:
    ScopedMacro(const std::string &name, const char *source) : name_(name) {
        // Fails closed if unable to claim unique name; never clear macrospace.
        unsigned short found = 0;
        if (RexxQueryMacro(name.c_str(), &found) == 0)
            throw std::runtime_error("macro name already in use");
        if (RexxAddMacro(name.c_str(), source, RXMACRO_SEARCH_BEFORE) != 0)
            throw std::runtime_error("RexxAddMacro failed");
        registered_ = true;
    }
    ~ScopedMacro() { if (registered_) RexxDropMacro(name_.c_str()); }
    const char *name() const { return name_.c_str(); }
};
int main(int argc, char **argv) {
    if (argc != 2) {
        std::cerr << "usage: hybrid-host PATH/TO/proxy_macro.rex\n";
        return 64;
    }
    try {
        // Make registered object routable while the interpreter runs.
        auto counter = std::make_shared<rx2cpp::CompiledCounter>(10);
        const std::string token = rx2cpp::Registry::instance().add(counter);
        auto name = std::string("RX2CPP_DEMO_") + std::to_string(getpid());
        ScopedMacro macro(name, argv[1]);
        Interpreter rex;
        // Native dynamic library is discoverable via LD_LIBRARY_PATH.
        // RegisterLibrary may return false if the package was already loaded.

        // Compiled C++ -> live ooRexx object -> native C++.
        auto array = rex.thread->NewArray(0);
        {
            rx2cpp::RexxObjectProxy proxy(rex.thread, array);
            proxy.send1("APPEND", rex.thread->String("retained"));
            auto count = proxy.send0("ITEMS");
            if (std::strcmp(rex.thread->ObjectToStringValue(count), "1") != 0)
                throw std::runtime_error("object message parity failed");
            auto equal = proxy.send1("==", proxy.raw());
            if (std::strcmp(rex.thread->ObjectToStringValue(equal), "1") != 0)
                throw std::runtime_error("interpreter object identity lost");
            std::cout << "native->interpreter-array: "
                      << rex.thread->ObjectToStringValue(count) << "\n";
        }
        // Interpreter runs a macrospace program, materialises an ooRexx proxy
        // and sends INCREMENT to the C++ object via NativeDispatch.
        auto args = rex.thread->ArrayOfThree(rex.thread->String(macro.name()),
                                            rex.thread->String(token.c_str()),
                                            rex.thread->String("7"));
        std::string driver_path = std::string(argv[1]);
        auto offset = driver_path.find_last_of('/');
        if (offset != std::string::npos) driver_path.resize(offset + 1);
        driver_path += "macro_driver.rex";
        auto reply = rex.thread->CallProgram(driver_path.c_str(), args);
        if (rex.thread->CheckCondition()) {
            auto info = rex.thread->GetConditionInfo();
            RexxCondition detail;
            if (info != NULLOBJECT) {
                rex.thread->DecodeConditionInfo(info, &detail);
                std::cerr << "Rexx condition: " << rex.thread->CString(detail.errortext)
                          << " / " << rex.thread->CString(detail.message)
                          << " code " << detail.code << "\n";
            }
            throw std::runtime_error("macrospace proxy/compiled callback failed");
        }
        if (reply == NULLOBJECT) throw std::runtime_error("macro returned null");
        std::cout << "interpreter-proxy->compiled-counter: "
                  << rex.thread->ObjectToStringValue(reply) << "\n";
        // The same macrospace route can execute interpreter-defined object
        // behaviour during a callback, then return to generated/native code.
        auto formattedArgs = rex.thread->ArrayOfThree(rex.thread->String(macro.name()),
                                                     rex.thread->String(token.c_str()),
                                                     rex.thread->String("@format"));
        auto formatted = rex.thread->CallProgram(driver_path.c_str(), formattedArgs);
        if (rex.thread->CheckCondition() || formatted == NULLOBJECT)
            throw std::runtime_error("nested interpreter method call failed");
        std::cout << "compiled->interpreter-formatter->compiled: "
                  << rex.thread->ObjectToStringValue(formatted) << "\n";
        std::cout << "compiled-counter-state: " << counter->value() << "\n";
        if (counter->value() != 17) throw std::runtime_error("callback state mismatch");
        rx2cpp::Registry::instance().remove(token);
        return 0;
    } catch (const std::exception &error) {
        std::cerr << "hybrid bridge failed: " << error.what() << "\n";
        return 1;
    }
}
