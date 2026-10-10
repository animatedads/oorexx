// SYSSLEEP must block only the invoking OS thread / Rexx activity.
// No process-wide mutex, event loop block, or global sleep state is allowed.
#include "rxbif_syssleep.hpp"
#include <atomic>
#include <cassert>
#include <chrono>
#include <iostream>
#include <thread>

using namespace rxbif_external;
namespace {
std::atomic<bool> entered{false};
int observedSleep(std::uint64_t usec) {
    // Announce immediately before entering the real per-thread nanosleep.
    entered.store(true, std::memory_order_release);
    return posixLongSleep(usec);
}
int zeroSleep(std::uint64_t usec) {assert(usec==0);return 0;}
} // namespace
int main() {
    std::atomic<bool> done{false};
    std::thread sleeping([&] {
        const auto answer=sysSleep({rx::Value::string("0.300")},observedSleep);
        assert(answer.bytes=="0");
        done.store(true,std::memory_order_release);
    });
    while(!entered.load(std::memory_order_acquire))std::this_thread::yield();
    std::thread working([&] {
        // This is another independent thread/activity using the SAME native
        // external-routine service while the first thread is asleep.
        for(int i=0;i<32;++i)
            assert(sysSleep({rx::Value::string("0")},zeroSleep).bytes=="0");
    });
    working.join();
    // The other activity made progress, to completion, before the sleeper.
    assert(!done.load(std::memory_order_acquire));
    sleeping.join();
    assert(done.load(std::memory_order_acquire));
    std::cout<<"PASS SYSSLEEP calling thread only; other activity completed during wait\n";
}
