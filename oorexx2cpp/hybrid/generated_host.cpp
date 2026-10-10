// The C++ class and interpreter proxy are GENERATED from accumulator.cls.
// This driver only supplies the interpreter lifecycle, registry and call test.
#include "generated.hpp"
#include "compiled_registry.hpp"
#include "rexx_object_proxy.hpp"
#include "minirexx_runtime.hpp"
#include <oorexxapi.h>
#include <rexx.h>
#include <rexxapidefs.h>
#include <unistd.h>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <cstring>

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
    ScopedMacro(std::string name, const char *source) : name_(std::move(name)) {
        unsigned short present = 0;
        if (RexxQueryMacro(name_.c_str(), &present) == 0)
            throw std::runtime_error("macrospace name collision");
        if (RexxAddMacro(name_.c_str(), source, RXMACRO_SEARCH_BEFORE) != 0)
            throw std::runtime_error("RexxAddMacro failed");
        registered_ = true;
    }
    ~ScopedMacro() { if (registered_) RexxDropMacro(name_.c_str()); }
    const char *name() const { return name_.c_str(); }
};
int main(int argc, char **argv) {
    if (argc != 3) {
        std::cerr << "usage: generated-host GENERATED_PROXY.rex GENERATED_DRIVER.rex\n";
        return 64;
    }
    try {
        auto instance = rx2cpp::makeGeneratedObject();
        // Construct compiled class instance using its actual generated INIT.
        instance->invoke("INIT", "10");
        const auto token = rx2cpp::Registry::instance().add(instance);
        auto second = rx2cpp::makeGeneratedObject();
        second->invoke("INIT", "2");
        const auto token2 = rx2cpp::Registry::instance().add(second);
        if (token == token2 || rx2cpp::Registry::instance().find(token).get() != instance.get())
            throw std::runtime_error("native identity registry mismatch");
        // Generated C++ classes retain the inherited .Object identity methods.
        auto nativeA = std::dynamic_pointer_cast<rx::ObjectDispatch>(instance);
        auto nativeB = std::dynamic_pointer_cast<rx::ObjectDispatch>(second);
        if (!nativeA || !nativeB) throw std::runtime_error("generated object lacks .Object dispatch");
        auto a = rx::Value::fromObject(nativeA), b = rx::Value::fromObject(nativeB);
        if (rx::sendBinary(a, "=", a).bytes != "1" ||
            rx::sendBinary(a, "=", b).bytes != "0" ||
            rx::sendBinary(a, "\\=", b).bytes != "1" ||
            rx::sendBinary(a, "==", a).bytes != "1")
            throw std::runtime_error("generated .Object inherited comparator mismatch");
        ScopedMacro macro("RX2CPP_GEN_" + std::to_string(getpid()), argv[1]);
        Interpreter rex;
        const auto call = [&](const std::string &target, const char *method,
                              RexxObjectPtr argument) -> RexxObjectPtr {
            auto args = rex.thread->ArrayOfFour(
                rex.thread->String(macro.name()), rex.thread->String(target.c_str()),
                rex.thread->String(method), argument);
            auto value = rex.thread->CallProgram(argv[2], args);
            if (rex.thread->CheckCondition() || value == NULLOBJECT) {
                auto info = rex.thread->GetConditionInfo();
                if (info != NULLOBJECT) {
                    RexxCondition detail;
                    rex.thread->DecodeConditionInfo(info, &detail);
                    std::cerr << "ooRexx condition: " << rex.thread->CString(detail.message)
                              << " code=" << detail.code << "\n";
                }
                throw std::runtime_error(std::string("generated proxy dispatch failed: ") + method);
            }
            return value;
        };
        const auto printCall = [&](const std::string &target, const char *selector, const char *argument) {
            auto response = call(target, selector, rex.thread->String(argument));
            std::cout << rex.thread->ObjectToStringValue(response) << '\n';
        };
        // Native C++ obtains and pins *live* ooRexx proxy instances.
        // CallProgram/macrospace creates the object once; subsequent SendMessage
        // operations reuse the pinned identity rather than cloning the object.
        {
            rx2cpp::RexxObjectProxy liveA(rex.thread, call(token, "@OBJECT", rex.thread->String("")));
            rx2cpp::RexxObjectProxy liveB(rex.thread, call(token2, "@OBJECT", rex.thread->String("")));
            if (std::string(rex.thread->ObjectToStringValue(liveA.send1("=", liveA.raw()))) != "1" ||
                std::string(rex.thread->ObjectToStringValue(liveA.send1("=", liveB.raw()))) != "0" ||
                std::string(rex.thread->ObjectToStringValue(liveA.send1("\\=", liveB.raw()))) != "1")
                throw std::runtime_error("interpreter proxy inherited identity mismatch");
            if (std::string(rex.thread->ObjectToStringValue(liveA.send1("INCREMENT", rex.thread->String("0")))) != "10")
                throw std::runtime_error("pinned interpreter->generated-native method dispatch failed");
            if (std::string(rex.thread->ObjectToStringValue(liveA.send0("CURRENT"))) != "10")
                throw std::runtime_error("pinned proxy could not retain native state");
            bool omittedRejected = false;
            try { (void)liveA.send0("INCREMENT"); }
            catch (const std::runtime_error &) { omittedRejected = true; }
            if (!omittedRejected) throw std::runtime_error("omitted argument was silently accepted");
            rex.thread->ClearCondition();
        }
        printCall(token, "INCREMENT", "7");
        printCall(token, "CURRENT", "");
        printCall(token2, "INCREMENT", "5");
        printCall(token, "INCREMENT", "-3");
        printCall(token2, "CURRENT", "");
        printCall(token, "CURRENT", "");
        const char binary[] = {'A', '\0', 'B'};
        auto response = call(token, "ECHO", rex.thread->NewString(binary, sizeof(binary)));
        auto responseString = rex.thread->ObjectToString(response);
        if (rex.thread->StringLength(responseString) != sizeof(binary) ||
            std::memcmp(rex.thread->StringData(responseString), binary, sizeof(binary)) != 0)
            throw std::runtime_error("binary .String round-trip lost content");
        std::cout << rex.thread->StringLength(responseString) << '\n';
        rx2cpp::Registry::instance().remove(token2);
        rx2cpp::Registry::instance().remove(token);
        return 0;
    } catch (const std::exception &exception) {
        std::cerr << "generated hybrid failure: " << exception.what() << "\n";
        return 1;
    }
}
