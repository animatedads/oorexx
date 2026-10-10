// Generated source for ooRexx's supported native package ABI.
// This module requires ooRexx's public C API, NOT the Alchemy Foreign Runtime.
#include <oorexxapi.h>
#include <oorexxerrors.h>
#include "compiled_registry.hpp"
#include "generated.hpp"
#include <string>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <stdexcept>

namespace rx2cpp {
Registry &Registry::instance() { static Registry registry; return registry; }
std::string Registry::add(std::shared_ptr<CompiledObject> obj) {
    if (!obj) throw std::invalid_argument("null compiled object");
    std::lock_guard<std::mutex> lock(gate_);
    auto token = std::string("instance-") + std::to_string(++next_);
    objects_.emplace(token, std::move(obj));
    return token;
}
void Registry::remove(const std::string &token) {
    std::lock_guard<std::mutex> lock(gate_);
    objects_.erase(token);
}
std::shared_ptr<CompiledObject> Registry::find(const std::string &token) {
    std::lock_guard<std::mutex> lock(gate_);
    const auto it = objects_.find(token);
    return it == objects_.end() ? nullptr : it->second;
}
// One native object may have several class-owned state slots. A stable
// slot index belongs to a class occurrence in the resolved inheritance
// graph, not the depth of the current C++/ooRexx activation call stack.
class ScopeRegistry {
    std::mutex gate_;
    std::unordered_map<std::string, std::unordered_map<int, std::shared_ptr<CompiledObject>>> scopes_;
public:
    std::shared_ptr<CompiledObject> at(const std::string &token, int slot,
                                        const std::string &className);
    void release(const std::string &token) {
        std::lock_guard<std::mutex> lock(gate_);
        scopes_.erase(token);
    }
    static ScopeRegistry &instance() {
        static ScopeRegistry registry;
        return registry;
    }
};
static std::string stringValue(RexxMethodContext *ctx, RexxObjectPtr object) {
    if (object == NULLOBJECT || !ctx->IsOfType(object, "STRING"))
        throw std::runtime_error("only ooRexx String scalar values are supported");
    auto s = ctx->ObjectToString(object);
    return std::string(ctx->StringData(s), ctx->StringLength(s));
}
static void report(RexxMethodContext *ctx, const char *message) {
    ctx->RaiseException1(Rexx_Error_Execution_user_defined, ctx->String(message));
}
static std::shared_ptr<CompiledObject> create(const std::string &className) {
    if (className == "ROOT") return makeGeneratedObject_ROOT();
    if (className == "SALT") return makeGeneratedObject_SALT();
    if (className == "PEPPER") return makeGeneratedObject_PEPPER();
    if (className == "DISH") return makeGeneratedObject_DISH();
    if (className == "GRAND") return makeGeneratedObject_GRAND();

    throw std::runtime_error("unsupported native class: " + className);
}
std::shared_ptr<CompiledObject> ScopeRegistry::at(const std::string &token, int slot,
                                                    const std::string &className) {
    std::lock_guard<std::mutex> lock(gate_);
    auto &slots = scopes_[token];
    auto it = slots.find(slot);
    if (it != slots.end()) return it->second;
    auto created = create(className);
    slots.emplace(slot, created);
    return created;
}
static RexxObjectPtr call(RexxMethodContext *ctx, RexxArrayObject args,
                          const std::string &className, const std::string &selector,
                          bool initializer, int scopeIndex, bool isRoot, const std::string &rootClass) {
    try {
        const size_t count = ctx->ArrayItems(args);
        if (count > 1) throw std::runtime_error("only zero or one argument supported");
        std::shared_ptr<CompiledObject> object;
        std::string token;
        if (initializer) {
            if (ctx->GetObjectVariable("RX2CPP_NATIVE_ID") != NULLOBJECT)
                throw std::runtime_error("native object already initialized");
            object = create(className);
        } else {
            // The root class owns the single lifetime token. A derived method
            // asks the root method for it; normal ooRexx dispatch chooses that
            // root implementation, and the derived method uses its own slot.
            RexxObjectPtr old = NULLOBJECT;
            if (isRoot) old = ctx->GetObjectVariable("RX2CPP_NATIVE_ID");
            else {
                auto definingRoot = ctx->FindClass(rootClass.c_str());
                if (definingRoot == NULLOBJECT)
                    throw std::runtime_error("compiled superclass missing: " + rootClass);
                // Explicit scope-directed message dispatch, bypassing a
                // possible subclass override of the internal accessor.
                old = ctx->ForwardMessage(ctx->GetSelf(), "RX2CPP_NATIVE_TOKEN",
                                          definingRoot, ctx->NewArray(0));
            }
            if (old == NULLOBJECT || ctx->CheckCondition())
                throw std::runtime_error("native object not initialized or root token inaccessible");
            token = stringValue(ctx, old);
            object = isRoot ? Registry::instance().find(token)
                            : ScopeRegistry::instance().at(token, scopeIndex, className);
            if (!object) throw std::runtime_error("expired native object handle");
        }
        std::string output;
        if (count == 0) output = object->invoke0(selector);
        else output = object->invoke(selector, stringValue(ctx, ctx->ArrayAt(args, 1)));
        if (initializer) {
            token = Registry::instance().add(object);
            ctx->SetObjectVariable("RX2CPP_NATIVE_ID", ctx->String(token.c_str()));
            return NULLOBJECT; // ooRexx INIT must not return an ordinary value
        }
        return ctx->NewString(output.data(), output.size());
    } catch (const std::exception &e) {
        report(ctx, e.what());
        return NULLOBJECT;
    }
}
}

RexxMethod2(RexxObjectPtr, rx_native_root_init, OSELF, self, ARGLIST, args)
{ (void)self; return rx2cpp::call(context, args, "ROOT", "INIT", 1, 1, 1, "ROOT"); }
RexxMethod2(RexxObjectPtr, rx_native_root_rootvalue, OSELF, self, ARGLIST, args)
{ (void)self; return rx2cpp::call(context, args, "ROOT", "ROOTVALUE", 0, 1, 1, "ROOT"); }
RexxMethod2(RexxObjectPtr, rx_native_root_who, OSELF, self, ARGLIST, args)
{ (void)self; return rx2cpp::call(context, args, "ROOT", "WHO", 0, 1, 1, "ROOT"); }
RexxMethod2(RexxObjectPtr, rx_native_salt_saltset, OSELF, self, ARGLIST, args)
{ (void)self; return rx2cpp::call(context, args, "SALT", "SALTSET", 0, 2, 0, "ROOT"); }
RexxMethod2(RexxObjectPtr, rx_native_salt_saltvalue, OSELF, self, ARGLIST, args)
{ (void)self; return rx2cpp::call(context, args, "SALT", "SALTVALUE", 0, 2, 0, "ROOT"); }
RexxMethod2(RexxObjectPtr, rx_native_salt_who, OSELF, self, ARGLIST, args)
{ (void)self; return rx2cpp::call(context, args, "SALT", "WHO", 0, 2, 0, "ROOT"); }
RexxMethod2(RexxObjectPtr, rx_native_pepper_pepperset, OSELF, self, ARGLIST, args)
{ (void)self; return rx2cpp::call(context, args, "PEPPER", "PEPPERSET", 0, 3, 0, "ROOT"); }
RexxMethod2(RexxObjectPtr, rx_native_pepper_peppervalue, OSELF, self, ARGLIST, args)
{ (void)self; return rx2cpp::call(context, args, "PEPPER", "PEPPERVALUE", 0, 3, 0, "ROOT"); }
RexxMethod2(RexxObjectPtr, rx_native_pepper_who, OSELF, self, ARGLIST, args)
{ (void)self; return rx2cpp::call(context, args, "PEPPER", "WHO", 0, 3, 0, "ROOT"); }
RexxMethod2(RexxObjectPtr, rx_native_dish_dishset, OSELF, self, ARGLIST, args)
{ (void)self; return rx2cpp::call(context, args, "DISH", "DISHSET", 0, 4, 0, "ROOT"); }
RexxMethod2(RexxObjectPtr, rx_native_dish_dishvalue, OSELF, self, ARGLIST, args)
{ (void)self; return rx2cpp::call(context, args, "DISH", "DISHVALUE", 0, 4, 0, "ROOT"); }
RexxMethod2(RexxObjectPtr, rx_native_grand_grandset, OSELF, self, ARGLIST, args)
{ (void)self; return rx2cpp::call(context, args, "GRAND", "GRANDSET", 0, 5, 0, "ROOT"); }
RexxMethod2(RexxObjectPtr, rx_native_grand_grandvalue, OSELF, self, ARGLIST, args)
{ (void)self; return rx2cpp::call(context, args, "GRAND", "GRANDVALUE", 0, 5, 0, "ROOT"); }


// Called in the defining root's method scope, including for subclass objects.
RexxMethod1(RexxObjectPtr, rx_native_token, OSELF, self)
{
    (void)self;
    return context->GetObjectVariable("RX2CPP_NATIVE_ID");
}

// COPY must be an explicit deep copy of every scope; reusing the root token
// aliases two Rexx objects and breaks identity and lifetime semantics.
RexxMethod0(RexxObjectPtr, rx_native_copy_reject)
{
    context->RaiseException1(Rexx_Error_Execution_user_defined,
        context->String("native COPY requires per-scope independent state; unsupported"));
    return NULLOBJECT;
}

RexxMethod1(RexxObjectPtr, rx_native_uninit, OSELF, self)
{
    (void)self;
    auto value = context->GetObjectVariable("RX2CPP_NATIVE_ID");
    if (value != NULLOBJECT) {
        const auto s = context->ObjectToString(value);
        auto token = std::string(context->StringData(s), context->StringLength(s));
        rx2cpp::ScopeRegistry::instance().release(token);
        rx2cpp::Registry::instance().remove(token);
        context->DropObjectVariable("RX2CPP_NATIVE_ID");
    }
    return NULLOBJECT;
}

static RexxMethodEntry nativeMethods[] = {
    REXX_METHOD(rx_native_root_init, rx_native_root_init),
    REXX_METHOD(rx_native_root_rootvalue, rx_native_root_rootvalue),
    REXX_METHOD(rx_native_root_who, rx_native_root_who),
    REXX_METHOD(rx_native_salt_saltset, rx_native_salt_saltset),
    REXX_METHOD(rx_native_salt_saltvalue, rx_native_salt_saltvalue),
    REXX_METHOD(rx_native_salt_who, rx_native_salt_who),
    REXX_METHOD(rx_native_pepper_pepperset, rx_native_pepper_pepperset),
    REXX_METHOD(rx_native_pepper_peppervalue, rx_native_pepper_peppervalue),
    REXX_METHOD(rx_native_pepper_who, rx_native_pepper_who),
    REXX_METHOD(rx_native_dish_dishset, rx_native_dish_dishset),
    REXX_METHOD(rx_native_dish_dishvalue, rx_native_dish_dishvalue),
    REXX_METHOD(rx_native_grand_grandset, rx_native_grand_grandset),
    REXX_METHOD(rx_native_grand_grandvalue, rx_native_grand_grandvalue),

    REXX_METHOD(rx_native_uninit, rx_native_uninit),
    REXX_METHOD(rx_native_token, rx_native_token),
    REXX_METHOD(rx_native_copy_reject, rx_native_copy_reject),
    REXX_LAST_METHOD()
};

static void RexxEntry loadPackage(RexxThreadContext *ctx) {
    // A native package normally only contributes routines/methods. We build
    // its PUBLIC class once and publish it to the ooRexx global environment.
    static const char declaration[] = "::class ROOT public\n::method INIT external \"LIBRARY rx2cpp_mixin rx_native_root_init\"\n::method ROOTVALUE external \"LIBRARY rx2cpp_mixin rx_native_root_rootvalue\"\n::method WHO external \"LIBRARY rx2cpp_mixin rx_native_root_who\"\n::method RX2CPP_NATIVE_TOKEN external \"LIBRARY rx2cpp_mixin rx_native_token\"\n::method UNINIT external \"LIBRARY rx2cpp_mixin rx_native_uninit\"\n::method COPY external \"LIBRARY rx2cpp_mixin rx_native_copy_reject\"\n::class SALT public mixinclass ROOT\n::method SALTSET external \"LIBRARY rx2cpp_mixin rx_native_salt_saltset\"\n::method SALTVALUE external \"LIBRARY rx2cpp_mixin rx_native_salt_saltvalue\"\n::method WHO external \"LIBRARY rx2cpp_mixin rx_native_salt_who\"\n::class PEPPER public mixinclass ROOT\n::method PEPPERSET external \"LIBRARY rx2cpp_mixin rx_native_pepper_pepperset\"\n::method PEPPERVALUE external \"LIBRARY rx2cpp_mixin rx_native_pepper_peppervalue\"\n::method WHO external \"LIBRARY rx2cpp_mixin rx_native_pepper_who\"\n::class DISH public subclass ROOT inherit SALT PEPPER\n::method DISHSET external \"LIBRARY rx2cpp_mixin rx_native_dish_dishset\"\n::method DISHVALUE external \"LIBRARY rx2cpp_mixin rx_native_dish_dishvalue\"\n::class GRAND public subclass DISH\n::method GRANDSET external \"LIBRARY rx2cpp_mixin rx_native_grand_grandset\"\n::method GRANDVALUE external \"LIBRARY rx2cpp_mixin rx_native_grand_grandvalue\"\n";
    const char *classNames[] = {
    "ROOT",
    "SALT",
    "PEPPER",
    "DISH",
    "GRAND",
    };
    // Validate the entire set before changing the global environment.
    for (const char *className : classNames) {
        if (ctx->DirectoryAt(ctx->GetGlobalEnvironment(), className) != NULLOBJECT) {
            ctx->RaiseException1(Rexx_Error_Execution_user_defined,
                                 ctx->String("native class name already registered"));
            return;
        }
    }
    auto pkg = ctx->LoadPackageFromData("rx2cpp-generated-rx2cpp_mixin", declaration, sizeof(declaration)-1);
    if (pkg == NULLOBJECT || ctx->CheckCondition()) return;
    auto classes = ctx->GetPackagePublicClasses(pkg);
    // Verify that all declared classes exist before publishing any.
    for (const char *className : classNames) {
        if (ctx->DirectoryAt(classes, className) == NULLOBJECT) {
            ctx->RaiseException1(Rexx_Error_Execution_user_defined,
                                 ctx->String("generated class not public"));
            return;
        }
    }
    for (const char *className : classNames) {
        auto cls = ctx->DirectoryAt(classes, className);
        ctx->DirectoryPut(ctx->GetGlobalEnvironment(), cls, className);
    }
}

static RexxPackageEntry generated_package_entry = {
    STANDARD_PACKAGE_HEADER
    REXX_CURRENT_INTERPRETER_VERSION,
    "rx2cpp_mixin", "0.17.0-dev1", loadPackage, nullptr, nullptr, nativeMethods
};
OOREXX_GET_PACKAGE(generated)
