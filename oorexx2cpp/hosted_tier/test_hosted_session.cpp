#include "HostedSession.hpp"
#include <iostream>
#include <stdexcept>
#include <string>

using rx2cpp::hosted::Condition;
using rx2cpp::hosted::Session;
static std::string needed(std::optional<Session::Object> &value) {
    if (!value) throw std::runtime_error("missing ooRexx result object");
    return value->asString();
}
static void expect(const std::string &actual, const std::string &expected) {
    if (actual != expected) throw std::runtime_error("expected [" + expected + "] got [" + actual + "]");
}
int main() {
    try {
        Session s;
        auto dateClass = s.findClass("DateTime");
        auto y = s.integer(2021), m = s.integer(12), d = s.integer(25);
        auto date = s.send(dateClass, "NEW", {y, m, d});
        if (!date) throw std::runtime_error("DateTime NEW returned no object");
        auto wd = s.send(*date, "WEEKDAY");
        expect(needed(wd), "6");
        std::cout << "weekday=6\n";

        // Controlled synthetic error: must be consumed before a further valid send.
        try {
            (void)s.send(*date, "RX2CPP_UNKNOWN_SELECTOR");
            throw std::runtime_error("unknown message unexpectedly succeeded");
        } catch (const Condition &e) {
            if (e.code != 97001) throw;
            std::cout << "unknown=97001\n";
        }
        wd = s.send(*date, "WEEKDAY");
        expect(needed(wd), "6");
        std::cout << "cleared=6\n";

        const std::string makeSub = "return .DateTime~subclass('Rx2CppHosted')~new(2022, 1, 1)";
        auto old = s.runRoutineSource(makeSub);
        if (!old) throw std::runtime_error("could not create subclass object");
        auto defined = s.runRoutineSource(
           "use arg o; o~class~define('NEWVALUE', .Method~new('NEWVALUE', 'return self~weekday')); return 'YES'", {*old});
        expect(needed(defined), "YES");
        try {
            (void)s.send(*old, "NEWVALUE");
            throw std::runtime_error("existing subclass instance saw newly defined method");
        } catch (const Condition &e) {
            if (e.code != 97001) throw;
            std::cout << "old-instance=97001\n";
        }
        auto newer = s.runRoutineSource("use arg o; return o~class~new(2022, 1, 1)", {*old});
        if (!newer) throw std::runtime_error("could not create post-define object");
        auto answer = s.send(*newer, "NEWVALUE");
        expect(needed(answer), "6");
        std::cout << "new-instance=6\n";

        auto binary = s.runRoutineSource("return '410042'x");
        const std::string raw = needed(binary);
        if (raw.size() != 3 || raw[0] != 'A' || raw[1] != '\0' || raw[2] != 'B')
            throw std::runtime_error("binary string did not survive");
        std::cout << "binary-bytes=3\n";

        auto evaluated = s.runRoutineSource(
           "use arg o; interpret 'x = o~newvalue'; return x", {*newer});
        expect(needed(evaluated), "6");
        std::cout << "interpret=6\n";

        // Handles intentionally outlive the Session facade; global pinning keeps the
        // native interpreter alive until the final handle is released.
        std::optional<Session::Object> held;
        {
            Session isolated;
            held.emplace(isolated.string("stable"));
        }
        expect(held->asString(), "stable");
        held.reset();
        std::cout << "lifetime=stable\n";

        // Never silently route an object from one interpreter into another.
        {
            Session other;
            auto alien = other.string("X");
            try {
                (void)s.send(*date, "STRING", {alien});
                throw std::runtime_error("cross-session argument unexpectedly accepted");
            } catch (const std::invalid_argument &) {
                std::cout << "cross-session=rejected\n";
            }
        }
        std::cout << "PASS hosted-session\n";
    } catch (const std::exception &e) {
        std::cerr << "FAIL hosted-session: " << e.what() << '\n';
        return 1;
    }
}
