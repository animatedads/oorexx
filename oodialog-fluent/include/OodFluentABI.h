// Architecture: Tom Dyer. Code: ChatGPT (GPT-6).
// Narrow C-compatible interface for the future ooRexx native package / WinUI DLL.
#ifndef OOD_FLUENT_ABI_H
#define OOD_FLUENT_ABI_H
#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32) && defined(OODF_BUILD_DLL)
#  define OODF_API __declspec(dllexport)
#elif defined(_WIN32) && defined(OODF_USE_DLL)
#  define OODF_API __declspec(dllimport)
#else
#  define OODF_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct OodfSession OodfSession;

typedef enum OodfStatus {
    OODF_OK = 0,
    OODF_INVALID_ARGUMENT = 1,
    OODF_CATALOGUE_ERROR = 2,
    OODF_UNKNOWN_CONTROL = 3,
    OODF_EXPERIMENTAL_DISABLED = 4,
    OODF_INVALID_PROPERTY = 5,
    OODF_INVALID_EVENT = 6,
    OODF_INVALID_HANDLER = 7,
    OODF_STALE_OCCURRENCE = 8,
    OODF_NO_EVENT = 9,
    OODF_BUFFER_TOO_SMALL = 10,
    OODF_INTERNAL_ERROR = 11
} OodfStatus;

// All strings use UTF-8. Values are copied; no callers may retain native pointers.
// The application must never treat the native session as its business model.
OODF_API OodfStatus oodf_open(const char *cataloguePath, int enableExperimental, OodfSession **out);
OODF_API OodfStatus oodf_create(OodfSession *session, int64_t resourceId, const char *type, uint64_t *uid);
// Preserve a resource author's stable occurrence identity across renderers and reopens.
// UID 0 and any previously-issued UID in this session are rejected, even after removal.
OODF_API OodfStatus oodf_create_authored(OodfSession *session, int64_t resourceId,
                                        const char *type, uint64_t authoredUid, uint64_t *uid);
OODF_API OodfStatus oodf_set(OodfSession *session, uint64_t uid, const char *property, const char *value);
OODF_API OodfStatus oodf_bind(OodfSession *session, uint64_t uid, const char *event, const char *handler);
OODF_API OodfStatus oodf_raise(OodfSession *session, uint64_t uid, const char *event, const char *value, int *queued);
OODF_API OodfStatus oodf_remove(OodfSession *session, uint64_t uid);

typedef struct OodfEventBuffer {
    int64_t resourceId;
    uint64_t uid;
    uint64_t revision;
    char *eventName;
    size_t eventNameCapacity;
    size_t eventNameRequired;
    char *eventValue;
    size_t eventValueCapacity;
    size_t eventValueRequired;
    char *handler;
    size_t handlerCapacity;
    size_t handlerRequired;
} OodfEventBuffer;

// A short buffer returns OODF_BUFFER_TOO_SMALL, sets Required fields (including
// terminating NUL), and does NOT consume the event. Re-call with larger buffers.
OODF_API OodfStatus oodf_poll(OodfSession *session, OodfEventBuffer *event);
OODF_API void oodf_close(OodfSession *session);
// Error detail is thread-local; copy it before the next call on this thread.
OODF_API const char *oodf_last_error(void);

#ifdef __cplusplus
}
#endif
#endif
