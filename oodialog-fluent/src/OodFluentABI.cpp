// Architecture: Tom Dyer. Code: ChatGPT (GPT-6).
#include "OodFluentABI.h"
#include "OodFluentCore.hpp"

#include <cstring>
#include <memory>
#include <mutex>
#include <new>
#include <optional>
#include <string>

using namespace oodfluent;

struct OodfSession {
    // Native XAML event delegates run on the HWND thread, while ooDialog's
    // Rexx activity polls and binds on a different thread. Protect the whole
    // model + pending retry envelope, not just the deque of events.
    std::mutex mutex;
    Catalogue catalogue;
    std::unique_ptr<Session> model;
    std::optional<Event> nextEvent;
};

namespace {
thread_local std::string lastError;

OodfStatus mapped(ErrorCode code) {
    switch (code) {
    case ErrorCode::InvalidCatalogue: return OODF_CATALOGUE_ERROR;
    case ErrorCode::UnknownControl: return OODF_UNKNOWN_CONTROL;
    case ErrorCode::ExperimentalDisabled: return OODF_EXPERIMENTAL_DISABLED;
    case ErrorCode::InvalidProperty: return OODF_INVALID_PROPERTY;
    case ErrorCode::InvalidEvent: return OODF_INVALID_EVENT;
    case ErrorCode::InvalidHandler: return OODF_INVALID_HANDLER;
    case ErrorCode::StaleOccurrence: return OODF_STALE_OCCURRENCE;
    }
    return OODF_INTERNAL_ERROR;
}

template<typename Function>
OodfStatus safe(Function function) noexcept {
    try {
        lastError.clear();
        return function();
    } catch (const Error &error) {
        lastError = error.what();
        return mapped(error.code());
    } catch (const std::exception &error) {
        lastError = error.what();
        return OODF_INTERNAL_ERROR;
    } catch (...) {
        lastError = "unknown native exception";
        return OODF_INTERNAL_ERROR;
    }
}

bool bad(const void *pointer) { return pointer == nullptr; }

void copy(const std::string &source, char *target) {
    std::memcpy(target, source.c_str(), source.size() + 1);
}
} // namespace

extern "C" {

OodfStatus oodf_open(const char *cataloguePath, int enableExperimental, OodfSession **out) {
    return safe([&] {
        if (bad(cataloguePath) || bad(out)) return OODF_INVALID_ARGUMENT;
        *out = nullptr;
        auto result = std::make_unique<OodfSession>();
        result->catalogue = Catalogue::fromTsv(cataloguePath);
        result->model = std::make_unique<Session>(result->catalogue, enableExperimental != 0);
        *out = result.release();
        return OODF_OK;
    });
}

OodfStatus oodf_create(OodfSession *session, int64_t resourceId, const char *type, uint64_t *uid) {
    return safe([&] {
        if (bad(session) || bad(type) || bad(uid)) return OODF_INVALID_ARGUMENT;
        std::lock_guard<std::mutex> lock(session->mutex);
        *uid = session->model->create(resourceId, type);
        return OODF_OK;
    });
}

OodfStatus oodf_create_authored(OodfSession *session, int64_t resourceId, const char *type,
                               uint64_t authoredUid, uint64_t *uid) {
    return safe([&] {
        if (bad(session) || bad(type) || bad(uid)) return OODF_INVALID_ARGUMENT;
        std::lock_guard<std::mutex> lock(session->mutex);
        *uid = session->model->createWithUid(resourceId, type, authoredUid);
        return OODF_OK;
    });
}

OodfStatus oodf_set(OodfSession *session, uint64_t uid, const char *property, const char *value) {
    return safe([&] {
        if (bad(session) || bad(property) || bad(value)) return OODF_INVALID_ARGUMENT;
        std::lock_guard<std::mutex> lock(session->mutex);
        session->model->set(uid, property, value);
        return OODF_OK;
    });
}

OodfStatus oodf_bind(OodfSession *session, uint64_t uid, const char *event, const char *handler) {
    return safe([&] {
        if (bad(session) || bad(event) || bad(handler)) return OODF_INVALID_ARGUMENT;
        std::lock_guard<std::mutex> lock(session->mutex);
        session->model->bind(uid, event, handler);
        return OODF_OK;
    });
}

OodfStatus oodf_raise(OodfSession *session, uint64_t uid, const char *event, const char *value, int *queued) {
    return safe([&] {
        if (bad(session) || bad(event) || bad(value) || bad(queued)) return OODF_INVALID_ARGUMENT;
        std::lock_guard<std::mutex> lock(session->mutex);
        *queued = session->model->raise(uid, event, value) ? 1 : 0;
        return OODF_OK;
    });
}

OodfStatus oodf_remove(OodfSession *session, uint64_t uid) {
    return safe([&] {
        if (bad(session)) return OODF_INVALID_ARGUMENT;
        std::lock_guard<std::mutex> lock(session->mutex);
        session->model->remove(uid);
        if (session->nextEvent && session->nextEvent->uid == uid) session->nextEvent.reset();
        return OODF_OK;
    });
}

OodfStatus oodf_poll(OodfSession *session, OodfEventBuffer *out) {
    return safe([&] {
        if (bad(session) || bad(out)) return OODF_INVALID_ARGUMENT;
        std::lock_guard<std::mutex> lock(session->mutex);
        if (!session->nextEvent) {
            Event next{};
            if (!session->model->take(next)) return OODF_NO_EVENT;
            session->nextEvent = std::move(next);
        }
        const auto &event = *session->nextEvent;
        out->resourceId = event.resourceId;
        out->uid = event.uid;
        out->revision = event.revision;
        out->eventNameRequired = event.name.size() + 1;
        out->eventValueRequired = event.value.size() + 1;
        out->handlerRequired = event.handler.size() + 1;
        if (bad(out->eventName) || bad(out->eventValue) || bad(out->handler) ||
            out->eventNameCapacity < out->eventNameRequired ||
            out->eventValueCapacity < out->eventValueRequired ||
            out->handlerCapacity < out->handlerRequired)
            return OODF_BUFFER_TOO_SMALL;
        copy(event.name, out->eventName);
        copy(event.value, out->eventValue);
        copy(event.handler, out->handler);
        session->nextEvent.reset();
        return OODF_OK;
    });
}

void oodf_close(OodfSession *session) { delete session; }
const char *oodf_last_error(void) { return lastError.c_str(); }

} // extern C
