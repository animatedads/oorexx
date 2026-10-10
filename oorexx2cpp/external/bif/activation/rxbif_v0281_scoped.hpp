#pragma once
// BIF-only optional v0.28.1 caller-activation binding.
// Copyright (c) 2026 BIF addon contributors. See LICENSE-ADDON.txt.
// Nothing here changes rx2cpp's runtime or compiler.
// Each thread has its own active binding; nesting restores the prior binding.
// Guarding the identity of the live frame AND BIF runtime prevents accidental
// concurrent access to unqualified rx::Variables / BifRuntime mutable state.
#include "rxbif_v028_activation.hpp"
#include <mutex>
#include <thread>
#include <unordered_map>
#include <stdexcept>
#include <string>
#include <utility>

namespace rxbif_v0281 {
struct Active {
    rx::BifRuntime* bif = nullptr;             // borrowed; never owned
    rx::Variables* vars = nullptr;              // borrowed; never owned
    rxbif_v028::FrameSupplier frame;           // can query caller per call
    rxbif_v028::ControlProvider control;       // cannot invent trap state
    std::thread::id thread;
};

class ScopedActivation final {
public:
    ScopedActivation(rx::BifRuntime& bif, rx::Variables& vars,
                     rxbif_v028::FrameSupplier frame = {},
                     rxbif_v028::ControlProvider control = {})
        : current_{&bif,&vars,std::move(frame),std::move(control),std::this_thread::get_id()} {
        // Validation is done before binding any state. This checks the REAL
        // numeric setting on the present activation, not a cached snapshot.
        rxbif_breadth::validateNumericContext(rx::frameNumeric(vars));
        auto& reg=registry();
        std::lock_guard<std::mutex> lock(reg.mutex);
        // Atomic preflight: a failed second key cannot leave the first leased.
        check(reg,&bif,"BIF runtime");
        check(reg,&vars,"variable activation");
        lease(reg,&bif); lease(reg,&vars);
        previous_=active();
        active()=&current_;
        engaged_=true;
    }
    ScopedActivation(const ScopedActivation&)=delete;
    ScopedActivation& operator=(const ScopedActivation&)=delete;
    ScopedActivation(ScopedActivation&&)=delete;
    ScopedActivation& operator=(ScopedActivation&&)=delete;
    ~ScopedActivation() noexcept {
        if (!engaged_) return;
        // The object must be constructed and destroyed on the SAME thread.
        // Cross-thread ownership transfers are intentionally unsupported.
        if (current_.thread != std::this_thread::get_id()) std::terminate();
        active()=previous_;
        auto& reg=registry();
        std::lock_guard<std::mutex> lock(reg.mutex);
        unlease(reg,current_.bif);
        unlease(reg,current_.vars);
    }
    static const Active& current() {
        const Active* p=active();
        if (!p || p->thread!=std::this_thread::get_id() || !p->bif || !p->vars)
            throw std::runtime_error("BIF v0.28.1: original thread activation is not bound");
        return *p;
    }
private:
    struct Owner { std::thread::id thread; std::size_t depth; };
    struct Registry { std::mutex mutex; std::unordered_map<const void*,Owner> leases; };
    static Registry& registry() { static Registry instance; return instance; }
    static Active*& active() { static thread_local Active* current=nullptr; return current; }
    static void check(Registry& reg, const void* key, const char* name) {
        auto p=reg.leases.find(key);
        if (p!=reg.leases.end() && p->second.thread!=std::this_thread::get_id())
            throw std::runtime_error(std::string("BIF v0.28.1: concurrent reuse of ")+name);
    }
    static void lease(Registry& reg, const void* key) {
        auto p=reg.leases.find(key);
        if (p==reg.leases.end()) reg.leases.emplace(key,Owner{std::this_thread::get_id(),1});
        else ++p->second.depth;
    }
    static void unlease(Registry& reg, const void* key) noexcept {
        auto p=reg.leases.find(key);
        if (p==reg.leases.end()) std::terminate();
        if (--p->second.depth==0) reg.leases.erase(p);
    }
    Active current_;
    Active* previous_ = nullptr;
    bool engaged_ = false;
};

class ThreadRouter final {
public:
    // Resolve the BIF runtime, pool and suppliers every invocation. Never retain
    // a pointer that might outlive a compiled local PROCEDURE or SELF method.
    rx::Value invoke(std::string name, const std::vector<rxbif_v028::Slot>& args={}) const {
        const Active& a=ScopedActivation::current();
        // Requery numeric context through Router's per-call pool supplier.
        // No fallback is added here; v0.13 typed fail-closed rules remain.
        rxbif_v028::Router route(*a.bif,[&a]{return a.vars;},a.frame,a.control);
        return route.invoke(std::move(name),args);
    }
};
} // namespace rxbif_v0281
