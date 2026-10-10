#ifndef RX2CPP_REXX_OBJECT_PROXY_HPP
#define RX2CPP_REXX_OBJECT_PROXY_HPP
#include <oorexxapi.h>
#include <stdexcept>
#include <string>

namespace rx2cpp {
// Interpreter-owned object. References survive an intervening CallProgram
// because a global reference is held. Scope: one interpreter & owning thread;
// do not share across threads or outlive the owning RexxInstance.
class RexxObjectProxy {
    RexxThreadContext *thread_;
    RexxObjectPtr reference_;
public:
    RexxObjectProxy(RexxThreadContext *thread, RexxObjectPtr object)
        : thread_(thread), reference_(thread->RequestGlobalReference(object)) {
        if (reference_ == NULLOBJECT) throw std::runtime_error("unable to pin Rexx object");
    }
    RexxObjectProxy(const RexxObjectProxy &) = delete;
    RexxObjectProxy &operator=(const RexxObjectProxy &) = delete;
    ~RexxObjectProxy() { thread_->ReleaseGlobalReference(reference_); }
    RexxObjectPtr raw() const { return reference_; }
    RexxObjectPtr send0(const char *selector) const {
        auto result = thread_->SendMessage0(reference_, selector);
        if (thread_->CheckCondition()) throw std::runtime_error(std::string("Rexx condition in ") + selector);
        return result;
    }
    RexxObjectPtr send1(const char *selector, RexxObjectPtr value) const {
        auto result = thread_->SendMessage1(reference_, selector, value);
        if (thread_->CheckCondition()) throw std::runtime_error(std::string("Rexx condition in ") + selector);
        return result;
    }
};
}
#endif
