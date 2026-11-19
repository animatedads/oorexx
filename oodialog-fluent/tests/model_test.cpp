// Architecture: Tom Dyer. Code: ChatGPT (GPT-6).
#include "OodFluentCore.hpp"
#include "OodFluentABI.h"

#include <cstdlib>
#include <atomic>
#include <chrono>
#include <functional>
#include <iostream>
#include <cstring>
#include <limits>
#include <string>
#include <thread>

using namespace oodfluent;

namespace {
int checks = 0;
int failures = 0;

void check(bool result, const char *expression, int line) {
    ++checks;
    if (!result) {
        ++failures;
        std::cerr << "FAIL line " << line << ": " << expression << '\n';
    }
}
#define CHECK(expr) check((expr), #expr, __LINE__)

void expects(ErrorCode code, const std::function<void()> &action) {
    bool matched = false;
    try {
        action();
    } catch (const Error &error) {
        matched = error.code() == code;
    }
    CHECK(matched);
}
} // namespace

int main(int argc, char **argv) {
    if (argc != 2) {
        std::cerr << "usage: model_test catalogue/controls.tsv\n";
        return 2;
    }
    try {
        auto catalogue = Catalogue::fromTsv(argv[1]);
        CHECK(catalogue.size() >= 70);
        CHECK(catalogue.type("ToggleSwitch").renderer == "winui3");
        CHECK(catalogue.type("Button").legacy == "ButtonControl");
        CHECK(catalogue.type("TableView").availability == "experimental");
        CHECK(catalogue.type("InkCanvas").availability == "experimental");
        CHECK(catalogue.type("Chart").availability == "experimental");
        CHECK(catalogue.type("WebView2").renderer == "webview2");
        CHECK(catalogue.type("MicaBackdrop").renderer == "composition");

        Session first(catalogue);
        const auto a = first.create(-1, "Button");
        const auto b = first.create(-1, "Button");
        CHECK(a == Session::AutomaticUidBase);
        CHECK(b == Session::AutomaticUidBase + 1);
        CHECK(a != b);
        CHECK(first.control(a).resourceId == first.control(b).resourceId);
        CHECK(first.size() == 2);
        CHECK(first.control(a).type == "Button");
        CHECK(first.control(a).revision == 0);
        const auto authored = first.createWithUid(-1, "Button", 881005);
        CHECK(authored == 881005);
        CHECK(first.control(authored).resourceId == -1);
        // An authored UID must not collide with earlier auto allocations,
        // regardless of creation order (review A1, REQ-00003737).
        const auto lowAuthored = first.createWithUid(1001, "Button", 1);
        CHECK(lowAuthored == 1);
        CHECK(lowAuthored != a);
        first.remove(lowAuthored);
        expects(ErrorCode::StaleOccurrence, [&] { first.createWithUid(1001, "Button", 1); });
        expects(ErrorCode::StaleOccurrence, [&] { first.createWithUid(1001, "Button", Session::AutomaticUidBase); });
        expects(ErrorCode::StaleOccurrence, [&] { first.createWithUid(1001, "Button", std::numeric_limits<std::uint64_t>::max()); });
        expects(ErrorCode::StaleOccurrence, [&] { first.createWithUid(9, "Button", 881005); });
        expects(ErrorCode::StaleOccurrence, [&] { first.createWithUid(9, "Button", 0); });
        first.bind(authored, "click", "onAuthored");
        CHECK(first.raise(authored, "click", "proof"));
        Event authoredEvent{};
        CHECK(first.take(authoredEvent));
        CHECK(authoredEvent.uid == 881005);
        first.remove(authored);
        expects(ErrorCode::StaleOccurrence, [&] { first.createWithUid(9, "Button", 881005); });
        first.set(a, "text", "OK");
        CHECK(first.control(a).properties.at("text") == "OK");
        CHECK(first.control(a).revision == 1);
        first.set(a, "text", "OK"); // idempotent patch
        CHECK(first.control(a).revision == 1);
        first.set(a, "automationName", "Accept");
        CHECK(first.control(a).revision == 2);
        expects(ErrorCode::InvalidProperty, [&] { first.set(a, "isOn", "true"); });
        expects(ErrorCode::InvalidEvent, [&] { first.bind(a, "toggled", "onToggle"); });
        expects(ErrorCode::InvalidHandler, [&] { first.bind(a, "click", ""); });
        CHECK(!first.raise(a, "click", "ignored-without-binding"));
        CHECK(first.pending() == 0);

        first.bind(a, "click", "onAccept");
        first.bind(b, "click", "onSecond");
        CHECK(first.raise(a, "click", "one"));
        CHECK(first.raise(b, "click", "two"));
        CHECK(first.pending() == 2);
        Event delivered{};
        CHECK(first.take(delivered));
        CHECK(delivered.uid == a);
        CHECK(delivered.resourceId == -1);
        CHECK(delivered.name == "click");
        CHECK(delivered.value == "one");
        CHECK(delivered.handler == "onAccept");
        CHECK(delivered.revision == 2);

        CHECK(first.raise(a, "click", "discard-on-delete"));
        first.remove(a);
        CHECK(first.size() == 1);
        CHECK(first.pending() == 1);
        expects(ErrorCode::StaleOccurrence, [&] { first.set(a, "text", "late"); });
        expects(ErrorCode::StaleOccurrence, [&] { first.raise(a, "click", "late"); });
        CHECK(first.take(delivered));
        CHECK(delivered.uid == b);
        CHECK(delivered.handler == "onSecond");
        CHECK(!first.take(delivered));
        first.clear();
        CHECK(first.size() == 0);
        CHECK(first.pending() == 0);
        expects(ErrorCode::StaleOccurrence, [&] { first.remove(b); });

        const auto newUid = first.create(2401, "ToggleSwitch");
        CHECK(newUid == Session::AutomaticUidBase + 2);
        CHECK(newUid != a && newUid != b); // never recycle within session
        first.set(newUid, "isOn", "true");
        first.bind(newUid, "toggled", "onNightModeChanged");
        CHECK(first.raise(newUid, "toggled", "true"));
        CHECK(first.take(delivered));
        CHECK(delivered.resourceId == 2401);
        CHECK(delivered.name == "toggled");
        CHECK(delivered.value == "true");

        expects(ErrorCode::ExperimentalDisabled, [&] { first.create(5001, "TableView"); });
        expects(ErrorCode::ExperimentalDisabled, [&] { first.create(5002, "Chart"); });
        expects(ErrorCode::ExperimentalDisabled, [&] { first.create(5003, "InkCanvas"); });
        expects(ErrorCode::UnknownControl, [&] { first.create(6, "FutureImaginaryControl"); });
        expects(ErrorCode::InvalidCatalogue, [&] { (void)Catalogue::fromTsv("not-a-catalogue.tsv"); });

        Session experimental(catalogue, true);
        const auto special = experimental.create(6001, "TableView");
        CHECK(experimental.control(special).type == "TableView");

        // The exported, C-compatible seam must preserve the same contract.
        OodfSession *abi = nullptr;
        CHECK(oodf_open(argv[1], 0, &abi) == OODF_OK);
        CHECK(abi != nullptr);
        uint64_t abiUid = 0;
        CHECK(oodf_create(abi, 49, "InfoBar", &abiUid) == OODF_OK);
        CHECK(abiUid != 0);
        CHECK(oodf_set(abi, abiUid, "message", "Saved") == OODF_OK);
        CHECK(oodf_set(abi, abiUid, "isOn", "invalid") == OODF_INVALID_PROPERTY);
        CHECK(std::strlen(oodf_last_error()) > 0);
        CHECK(oodf_bind(abi, abiUid, "closed", "onInfoBarClosed") == OODF_OK);
        int queued = -1;
        CHECK(oodf_raise(abi, abiUid, "closed", "échec", &queued) == OODF_OK);
        CHECK(queued == 1);
        char name[24]{};
        char value[32]{};
        char handler[32]{};
        OodfEventBuffer eventBuffer{};
        eventBuffer.eventName = name;
        eventBuffer.eventNameCapacity = sizeof name;
        eventBuffer.eventValue = value;
        eventBuffer.eventValueCapacity = 1; // too small; must not consume event
        eventBuffer.handler = handler;
        eventBuffer.handlerCapacity = sizeof handler;
        CHECK(oodf_poll(abi, &eventBuffer) == OODF_BUFFER_TOO_SMALL);
        CHECK(eventBuffer.eventValueRequired == std::strlen("échec") + 1);
        CHECK(eventBuffer.eventNameRequired == std::strlen("closed") + 1);
        eventBuffer.eventValueCapacity = sizeof value;
        CHECK(oodf_poll(abi, &eventBuffer) == OODF_OK);
        CHECK(eventBuffer.uid == abiUid);
        CHECK(eventBuffer.resourceId == 49);
        CHECK(std::string(name) == "closed");
        CHECK(std::string(value) == "échec");
        CHECK(std::string(handler) == "onInfoBarClosed");
        CHECK(oodf_poll(abi, &eventBuffer) == OODF_NO_EVENT);
        uint64_t stableUid = 0;
        CHECK(oodf_create_authored(abi, -1, "Button", 99887766, &stableUid) == OODF_OK);
        CHECK(stableUid == 99887766);
        CHECK(oodf_create_authored(abi, 70, "Button", 99887766, &stableUid) == OODF_STALE_OCCURRENCE);
        CHECK(oodf_remove(abi, 99887766) == OODF_OK);
        CHECK(oodf_create_authored(abi, 70, "Button", 99887766, &stableUid) == OODF_STALE_OCCURRENCE);
        CHECK(oodf_raise(abi, abiUid, "closed", "cancelled", &queued) == OODF_OK);
        CHECK(oodf_poll(abi, &eventBuffer) == OODF_OK); // already popped
        CHECK(oodf_raise(abi, abiUid, "closed", "drop-before-delivery", &queued) == OODF_OK);
        eventBuffer.eventValueCapacity = 1; // held internally, not yet delivered
        CHECK(oodf_poll(abi, &eventBuffer) == OODF_BUFFER_TOO_SMALL);
        CHECK(oodf_remove(abi, abiUid) == OODF_OK);
        eventBuffer.eventValueCapacity = sizeof value;
        CHECK(oodf_poll(abi, &eventBuffer) == OODF_NO_EVENT);
        CHECK(oodf_set(abi, abiUid, "message", "stale") == OODF_STALE_OCCURRENCE);
        CHECK(oodf_create(abi, 4002, "InkCanvas", &abiUid) == OODF_EXPERIMENTAL_DISABLED);
        CHECK(oodf_create(abi, 4003, "NotAControl", &abiUid) == OODF_UNKNOWN_CONTROL);
        CHECK(oodf_create(nullptr, 3, "Button", &abiUid) == OODF_INVALID_ARGUMENT);
        oodf_close(abi);

        // WinUI callbacks and Rexx polling execute on different Windows
        // threads. ABI operations must serialize BOTH the event queue and
        // its buffer-too-small retry slot while preserving FIFO order.
        OodfSession *concurrent = nullptr;
        CHECK(oodf_open(argv[1], 0, &concurrent) == OODF_OK);
        uint64_t concurrentUid = 0;
        CHECK(oodf_create(concurrent, 9700, "TextBox", &concurrentUid) == OODF_OK);
        CHECK(oodf_bind(concurrent, concurrentUid, "textChanged", "onConcurrent") == OODF_OK);
        constexpr int messages = 300;
        std::atomic_bool producerOk{true};
        std::thread producer([&] {
            for (int n = 0; n < messages; ++n) {
                const auto payload = std::to_string(n);
                int queued = -1;
                if (oodf_raise(concurrent, concurrentUid, "textChanged", payload.c_str(), &queued) != OODF_OK || queued != 1)
                    producerOk = false;
            }
        });
        int received = 0;
        auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(10);
        while (received < messages && std::chrono::steady_clock::now() < deadline) {
            char evName[32]{}, evValue[32]{}, evHandler[32]{};
            OodfEventBuffer buffer{};
            buffer.eventName = evName;
            buffer.eventNameCapacity = sizeof evName;
            buffer.eventValue = evValue;
            buffer.eventValueCapacity = sizeof evValue;
            buffer.handler = evHandler;
            buffer.handlerCapacity = sizeof evHandler;
            auto result = oodf_poll(concurrent, &buffer);
            if (result == OODF_NO_EVENT) {
                std::this_thread::yield();
                continue;
            }
            CHECK(result == OODF_OK);
            if (result != OODF_OK) break;
            CHECK(std::string(evName) == "textChanged");
            CHECK(std::string(evValue) == std::to_string(received));
            CHECK(buffer.uid == concurrentUid);
            ++received;
        }
        producer.join();
        CHECK(producerOk.load());
        CHECK(received == messages);
        CHECK(oodf_remove(concurrent, concurrentUid) == OODF_OK);
        oodf_close(concurrent);
        OodfSession *badAbi = reinterpret_cast<OodfSession *>(0x1);
        CHECK(oodf_open("not-a-catalogue.tsv", 0, &badAbi) == OODF_CATALOGUE_ERROR);
        CHECK(badAbi == nullptr);

        std::cout << (failures == 0 ? "LOCAL_PASS " : "FAIL ") << checks - failures << '/'
                  << checks << " checks, " << catalogue.size() << " catalogue entries\n";
        return failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
    } catch (const std::exception &error) {
        std::cerr << "FAIL unexpected exception: " << error.what() << '\n';
        return EXIT_FAILURE;
    }
}
