#ifndef RX2CPP_HOSTED_SESSION_HPP
#define RX2CPP_HOSTED_SESSION_HPP

// Experimental ooRexx 5.3 hosted-tier bridge; not a standalone-runtime replacement.
// All calls, including destruction of the last Object, must run on the creator thread.
#include <oorexxapi.h>
#include <functional>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <thread>
#include <utility>
#include <vector>

namespace rx2cpp::hosted {

class Condition final : public std::runtime_error {
public:
    const wholenumber_t code;
    const wholenumber_t rc;
    Condition(wholenumber_t code_, wholenumber_t rc_, const std::string &message)
        : std::runtime_error(message), code(code_), rc(rc_) {}
};

class Session final {
    struct State {
        RexxInstance *instance = nullptr;
        RexxThreadContext *context = nullptr;
        std::thread::id owner = std::this_thread::get_id();

        State() {
            RexxOption options[1] = {};
            if (!RexxCreateInterpreter(&instance, &context, options) || !instance || !context)
                throw std::runtime_error("rx2cpp hosted: failed to create ooRexx interpreter");
        }
        State(const State &) = delete;
        State &operator=(const State &) = delete;
        ~State() noexcept {
            // The ooRexx thread context is never valid on a different thread.
            if (std::this_thread::get_id() != owner) std::terminate();
            if (instance) instance->Terminate();
        }
        void onOwnerThread() const {
            if (std::this_thread::get_id() != owner)
                throw std::logic_error("rx2cpp hosted: cross-thread interpreter use");
        }
        void check() const {
            onOwnerThread();
            if (!context->CheckCondition()) return;
            RexxDirectoryObject info = context->GetConditionInfo();
            RexxCondition condition{};
            if (info) context->DecodeConditionInfo(info, &condition);
            std::string message = "ooRexx condition";
            if (condition.message) {
                const char *data = context->StringData(condition.message);
                const size_t length = context->StringLength(condition.message);
                if (data) message.assign(data, length);
            }
            // Mandatory: stale interpreter conditions poison subsequent sends.
            context->ClearCondition();
            throw Condition(condition.code, condition.rc, message);
        }
    };

public:
    class Object final {
        friend class Session;
        std::shared_ptr<State> state_;
        RexxObjectPtr value_ = nullptr;

        Object(std::shared_ptr<State> state, RexxObjectPtr value)
            : state_(std::move(state)) {
            if (!value) throw std::runtime_error("rx2cpp hosted: null Rexx object");
            state_->onOwnerThread();
            value_ = state_->context->RequestGlobalReference(value);
            state_->check();
            if (!value_) throw std::runtime_error("rx2cpp hosted: failed global reference");
        }
        void release() noexcept {
            if (!value_) return;
            if (std::this_thread::get_id() != state_->owner) std::terminate();
            state_->context->ReleaseGlobalReference(value_);
            value_ = nullptr;
        }
    public:
        Object() = delete;
        Object(const Object &) = delete;
        Object &operator=(const Object &) = delete;
        Object(Object &&other) noexcept : state_(std::move(other.state_)), value_(std::exchange(other.value_, nullptr)) {}
        Object &operator=(Object &&other) noexcept {
            if (this != &other) {
                release();
                state_ = std::move(other.state_);
                value_ = std::exchange(other.value_, nullptr);
            }
            return *this;
        }
        ~Object() noexcept { release(); }
        std::string asString() const {
            if (!state_ || !value_) throw std::logic_error("rx2cpp hosted: moved object");
            state_->onOwnerThread();
            RexxStringObject str = state_->context->ObjectToString(value_);
            state_->check();
            if (!str) throw std::runtime_error("rx2cpp hosted: string conversion produced no object");
            const char *bytes = state_->context->StringData(str);
            const size_t length = state_->context->StringLength(str);
            state_->check();
            if (!bytes && length != 0) throw std::runtime_error("rx2cpp hosted: invalid string data");
            return bytes ? std::string(bytes, length) : std::string();
        }
    };

private:
    std::shared_ptr<State> state_ = std::make_shared<State>();
    using Args = std::initializer_list<std::reference_wrapper<const Object>>;
    RexxArrayObject packArgs(Args args) const {
        state_->onOwnerThread();
        RexxArrayObject a = state_->context->NewArray(args.size());
        state_->check();
        if (!a) throw std::runtime_error("rx2cpp hosted: cannot create arguments array");
        size_t i = 1;
        for (const Object &o : args) {
            if (o.state_ != state_ || !o.value_) throw std::invalid_argument("rx2cpp hosted: foreign or moved argument");
            state_->context->ArrayPut(a, o.value_, i++);
            state_->check();
        }
        return a;
    }
    std::optional<Object> capture(RexxObjectPtr result) const {
        state_->check();
        if (!result) return std::nullopt; // ooRexx methods can return no result object
        return Object(state_, result);
    }

public:
    Session() = default;
    Session(const Session &) = delete;
    Session &operator=(const Session &) = delete;
    Session(Session &&) = delete;
    Session &operator=(Session &&) = delete;

    Object findClass(const std::string &name) const {
        state_->onOwnerThread();
        RexxClassObject cls = state_->context->FindClass(name.c_str());
        state_->check();
        if (!cls) throw std::runtime_error("rx2cpp hosted: class not found: " + name);
        return Object(state_, cls);
    }
    Object integer(wholenumber_t n) const {
        state_->onOwnerThread();
        RexxObjectPtr r = state_->context->WholeNumber(n);
        state_->check();
        return Object(state_, r);
    }
    Object string(const std::string &s) const {
        state_->onOwnerThread();
        RexxObjectPtr r = state_->context->NewString(s.data(), s.size());
        state_->check();
        return Object(state_, r);
    }
    std::optional<Object> send(const Object &receiver, const std::string &selector, Args args = {}) const {
        state_->onOwnerThread();
        if (receiver.state_ != state_ || !receiver.value_)
            throw std::invalid_argument("rx2cpp hosted: foreign or moved receiver");
        RexxObjectPtr r = nullptr;
        if (args.size() == 0) r = state_->context->SendMessage0(receiver.value_, selector.c_str());
        else r = state_->context->SendMessage(receiver.value_, selector.c_str(), packArgs(args));
        return capture(r);
    }
    // An isolated ooRexx routine activation. This is NOT a native activation's INTERPRET.
    std::optional<Object> runRoutineSource(const std::string &source, Args args = {}) const {
        state_->onOwnerThread();
        RexxRoutineObject routine = state_->context->NewRoutine("rx2cpp-hosted", source.data(), source.size());
        state_->check();
        if (!routine) throw std::runtime_error("rx2cpp hosted: cannot compile routine source");
        return capture(state_->context->CallRoutine(routine, packArgs(args)));
    }
};
} // namespace rx2cpp::hosted
#endif
