// Architecture: Tom Dyer. Code: ChatGPT (GPT-6).
// ooRexx native routine package in the same DLL as the WinUI 3 provider.
// No XAML delegate executes Rexx; ooRexx explicitly drains queued events.
#include <oorexxapi.h>
#include "OodFluentIsland.h"

#include <charconv>
#include <atomic>
#include <cstdio>
#include <cstring>
#include <cstdint>
#include <functional>
#include <iomanip>
#include <limits>
#include <map>
#include <memory>
#include <mutex>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

struct Session {
    OodfSession *model = nullptr;
    OodfWinHost *host = nullptr;
    HWND parent = nullptr;
    DWORD rexxThread = 0;
    DWORD uiThread = 0;
};

std::mutex sessionsMutex;
std::map<uint64_t, std::unique_ptr<Session>> sessions;
uint64_t nextToken = 1;

// ooDialog's Rexx initDialog activity is NOT its HWND-owning thread.
// All C++/WinRT island operations run synchronously on the owning GUI thread,
// reached through a thread-scoped Win32 hook. This broker neither invokes Rexx
// from a native hook nor subclasses the user's dialog window.
constexpr UINT kGuiDispatchMessage = WM_APP + 0x2F71;
struct GuiAction {
    HWND target{};
    std::function<HRESULT()> invoke;
    HRESULT result = E_UNEXPECTED;
    std::atomic_bool completed{false};
};

std::mutex guiActionsMutex;
std::map<uintptr_t, GuiAction *> guiActions;
std::atomic<uintptr_t> nextGuiTicket{1};

void guiTrace(const char *stage) {
    if (!GetEnvironmentVariableA("OODF_LIFECYCLE_TRACE", nullptr, 0)) return;
    fprintf(stderr, "GUI_BRIDGE_STAGE %s thread=%lu\n", stage,
            static_cast<unsigned long>(GetCurrentThreadId()));
    fflush(stderr);
}

LRESULT CALLBACK guiThreadHook(int code, WPARAM wp, LPARAM lp) {
    if (code == HC_ACTION) {
        auto *message = reinterpret_cast<const CWPSTRUCT *>(lp);
        if (message && message->message == kGuiDispatchMessage) {
            GuiAction *action = nullptr;
            {
                std::lock_guard<std::mutex> lock(guiActionsMutex);
                auto found = guiActions.find(static_cast<uintptr_t>(message->wParam));
                if (found != guiActions.end() && found->second->target == message->hwnd) {
                    action = found->second;
                    guiActions.erase(found); // Prevent duplicate or re-entrant execution.
                }
            }
            if (action) {
                guiTrace("HOOK_INVOKE_BEGIN");
                try { action->result = action->invoke(); }
                catch (...) { action->result = E_FAIL; }
                action->completed.store(true, std::memory_order_release);
                guiTrace("HOOK_INVOKE_DONE");
            }
        }
    }
    return CallNextHookEx(nullptr, code, wp, lp);
}

HRESULT onDialogWindowThread(HWND window, std::function<HRESULT()> operation) {
    if (!IsWindow(window)) return HRESULT_FROM_WIN32(ERROR_INVALID_WINDOW_HANDLE);
    DWORD owner = GetWindowThreadProcessId(window, nullptr);
    if (!owner) return HRESULT_FROM_WIN32(GetLastError());
    if (owner == GetCurrentThreadId()) return operation();
    char optIn[2]{};
    if (GetEnvironmentVariableA("OODF_TEST_CROSS_THREAD_HOOK", optIn, sizeof(optIn)) != 1 || optIn[0] != '1')
        return RPC_E_WRONG_THREAD; // Diagnostic broker not yet release-qualified.
    guiTrace("HOOK_INSTALL_BEGIN");
    HHOOK hook = SetWindowsHookExW(WH_CALLWNDPROC, guiThreadHook, nullptr, owner);
    if (!hook) return HRESULT_FROM_WIN32(GetLastError());
    guiTrace("HOOK_INSTALLED");
    GuiAction action{window, std::move(operation)};
    auto ticket = nextGuiTicket.fetch_add(1);
    {
        std::lock_guard<std::mutex> lock(guiActionsMutex);
        guiActions.emplace(ticket, &action);
    }
    // SendMessage synchronizes the hook's execution and lifetime of the
    // stack-backed request. A bounded/cancellable broker is a later release
    // requirement; no request pointer is ever received from HWND messages.
    guiTrace("SEND_BEGIN");
    SendMessageW(window, kGuiDispatchMessage, static_cast<WPARAM>(ticket), 0);
    guiTrace("SEND_DONE");
    {
        std::lock_guard<std::mutex> lock(guiActionsMutex);
        guiActions.erase(ticket);
    }
    UnhookWindowsHookEx(hook);
    guiTrace("HOOK_UNINSTALLED");
    return action.completed.load(std::memory_order_acquire) ? action.result : E_UNEXPECTED;
}

RexxObjectPtr error(RexxCallContext *context, const std::string &detail) {
    context->RaiseException1(Rexx_Error_Invalid_argument_user_defined,
                             context->String(("ooDialog Fluent: " + detail).c_str()));
    return NULLOBJECT;
}

std::string hex(HRESULT hr) {
    std::ostringstream out;
    out << "HRESULT 0x" << std::uppercase << std::hex << static_cast<uint32_t>(hr);
    return out.str();
}

template <typename Integer>
bool decimal(const char *input, Integer &result) {
    if (!input || !*input) return false;
    const char *end = input + strlen(input);
    auto parsed = std::from_chars(input, end, result, 10);
    return parsed.ec == std::errc{} && parsed.ptr == end;
}

bool windowHandle(const char *text, HWND &window) {
    // ooDialog HWND text uses a 0x-prefixed hexadecimal representation.
    if (!text || text[0] != '0' || (text[1] != 'x' && text[1] != 'X')) return false;
    const char *first = text + 2;
    if (!*first) return false;
    uintptr_t value = 0;
    auto parsed = std::from_chars(first, first + strlen(first), value, 16);
    if (parsed.ec != std::errc{} || *parsed.ptr != '\0' || !value) return false;
    window = reinterpret_cast<HWND>(value);
    return IsWindow(window) != FALSE;
}

Session *get(RexxCallContext *context, const char *token) {
    uint64_t id = 0;
    if (!decimal(token, id)) {
        error(context, "invalid session token");
        return nullptr;
    }
    auto it = sessions.find(id);
    if (it == sessions.end()) {
        error(context, "session has closed or is unknown");
        return nullptr;
    }
    const DWORD caller = GetCurrentThreadId();
    if (it->second->rexxThread != caller && it->second->uiThread != caller) {
        error(context, "call must execute on the dialog's Rexx activity or UI thread");
        return nullptr;
    }
    return it->second.get();
}

bool occurrence(RexxCallContext *context, const char *text, uint64_t &uid) {
    if (decimal(text, uid) && uid != 0) return true;
    error(context, "invalid occurrence UID");
    return false;
}

std::wstring wide(const char *utf8) {
    int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8, -1, nullptr, 0);
    if (!length) throw std::runtime_error("invalid UTF-8");
    std::wstring result(static_cast<size_t>(length), L'\0');
    if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8, -1, result.data(), length))
        throw std::runtime_error("invalid UTF-8");
    result.pop_back();
    return result;
}

void put(RexxCallContext *context, RexxDirectoryObject directory,
         const char *key, const std::string &value) {
    context->DirectoryPut(directory, context->String(value.c_str()), key);
}

} // namespace

RexxRoutine3(RexxObjectPtr, OodfNativeOpen,
             CSTRING, hwnd, CSTRING, cataloguePath, int, experimental) {
    std::lock_guard<std::mutex> lock(sessionsMutex);
    HWND parent{};
    if (!windowHandle(hwnd, parent)) return error(context, "invalid ooDialog HWND (expect 0x-prefixed HWND)");
    if (experimental != 0 && experimental != 1) return error(context, "experimental must be 0 or 1");
    auto session = std::make_unique<Session>();
    auto status = oodf_open(cataloguePath, experimental, &session->model);
    if (status != OODF_OK) return error(context, oodf_last_error());
    session->parent = parent;
    session->rexxThread = GetCurrentThreadId();
    session->uiThread = GetWindowThreadProcessId(parent, nullptr);
    HRESULT result = onDialogWindowThread(parent, [&] {
        return oodf_win_open(parent, session->model, &session->host);
    });
    if (FAILED(result)) {
        oodf_close(session->model);
        return error(context, "WinUI host initialization failed: " + hex(result));
    }
    const auto token = nextToken++;
    sessions.emplace(token, std::move(session));
    return context->String(std::to_string(token).c_str());
}

RexxRoutine4(RexxObjectPtr, OodfNativeCreate,
             CSTRING, token, CSTRING, resourceId, CSTRING, kind, CSTRING, caption) {
    std::lock_guard<std::mutex> lock(sessionsMutex);
    Session *session = get(context, token);
    if (!session) return NULLOBJECT;
    int64_t id = 0;
    if (!decimal(resourceId, id)) return error(context, "resource ID must be a signed 64-bit integer");
    try {
        const std::wstring type = wide(kind), label = wide(caption);
        uint64_t uid = 0;
        HRESULT result = onDialogWindowThread(session->parent, [&] {
            return oodf_win_add(session->host, id, type.c_str(), label.c_str(), &uid);
        });
        if (FAILED(result)) return error(context, "control creation failed: " + hex(result));
        return context->String(std::to_string(uid).c_str());
    } catch (const std::exception &e) { return error(context, e.what()); }
}

RexxRoutine5(RexxObjectPtr, OodfNativeCreateAuthored,
             CSTRING, token, CSTRING, resourceId, CSTRING, kind,
             CSTRING, caption, CSTRING, authoredUidText) {
    std::lock_guard<std::mutex> lock(sessionsMutex);
    Session *session = get(context, token);
    if (!session) return NULLOBJECT;
    int64_t id = 0;
    uint64_t authoredUid = 0;
    if (!decimal(resourceId, id)) return error(context, "resource ID must be a signed 64-bit integer");
    if (!occurrence(context, authoredUidText, authoredUid)) return NULLOBJECT;
    try {
        const std::wstring type = wide(kind), label = wide(caption);
        uint64_t uid = 0;
        HRESULT result = onDialogWindowThread(session->parent, [&] {
            return oodf_win_add_authored(session->host, id, type.c_str(), label.c_str(), authoredUid, &uid);
        });
        if (FAILED(result)) return error(context, "authored occurrence creation failed: " + hex(result));
        return context->String(std::to_string(uid).c_str());
    } catch (const std::exception &e) { return error(context, e.what()); }
}

RexxRoutine4(RexxObjectPtr, OodfNativeSet,
             CSTRING, token, CSTRING, uidText, CSTRING, property, CSTRING, value) {
    std::lock_guard<std::mutex> lock(sessionsMutex);
    Session *session = get(context, token);
    if (!session) return NULLOBJECT;
    uint64_t uid{};
    if (!occurrence(context, uidText, uid)) return NULLOBJECT;
    try {
        auto name = wide(property), text = wide(value);
        HRESULT result = onDialogWindowThread(session->parent, [&] {
            return oodf_win_set(session->host, uid, name.c_str(), text.c_str());
        });
        if (FAILED(result)) return error(context, "property update failed: " + hex(result));
        return context->True();
    } catch (const std::exception &e) { return error(context, e.what()); }
}

RexxRoutine4(RexxObjectPtr, OodfNativeBind,
             CSTRING, token, CSTRING, uidText, CSTRING, eventName, CSTRING, handler) {
    std::lock_guard<std::mutex> lock(sessionsMutex);
    Session *session = get(context, token);
    if (!session) return NULLOBJECT;
    uint64_t uid{};
    if (!occurrence(context, uidText, uid)) return NULLOBJECT;
    auto result = oodf_bind(session->model, uid, eventName, handler);
    if (result != OODF_OK) return error(context, oodf_last_error());
    return context->True();
}

RexxRoutine5(RexxObjectPtr, OodfNativeMove,
             CSTRING, token, int, x, int, y, int, width, int, height) {
    std::lock_guard<std::mutex> lock(sessionsMutex);
    Session *session = get(context, token);
    if (!session) return NULLOBJECT;
    HRESULT result = onDialogWindowThread(session->parent, [&] {
        return oodf_win_move(session->host, x, y, width, height);
    });
    if (FAILED(result)) return error(context, "island resize failed: " + hex(result));
    return context->True();
}

RexxRoutine2(RexxObjectPtr, OodfNativeRemove, CSTRING, token, CSTRING, uidText) {
    std::lock_guard<std::mutex> lock(sessionsMutex);
    Session *session = get(context, token);
    if (!session) return NULLOBJECT;
    uint64_t uid{};
    if (!occurrence(context, uidText, uid)) return NULLOBJECT;
    HRESULT result = onDialogWindowThread(session->parent, [&] {
        return oodf_win_remove(session->host, uid);
    });
    if (FAILED(result)) return error(context, "control removal failed: " + hex(result));
    return context->True();
}

RexxRoutine1(RexxObjectPtr, OodfNativePoll, CSTRING, token) {
    std::lock_guard<std::mutex> lock(sessionsMutex);
    Session *session = get(context, token);
    if (!session) return NULLOBJECT;
    // Two-pass read is a lossless transaction. The first call can return
    // required sizes without removing the event from its queue.
    OodfEventBuffer buffer{};
    auto status = oodf_poll(session->model, &buffer);
    if (status == OODF_NO_EVENT) return context->Nil();
    if (status != OODF_BUFFER_TOO_SMALL) return error(context, oodf_last_error());
    std::vector<char> name(buffer.eventNameRequired), value(buffer.eventValueRequired),
                      handler(buffer.handlerRequired);
    buffer.eventName = name.data();
    buffer.eventNameCapacity = name.size();
    buffer.eventValue = value.data();
    buffer.eventValueCapacity = value.size();
    buffer.handler = handler.data();
    buffer.handlerCapacity = handler.size();
    status = oodf_poll(session->model, &buffer);
    if (status != OODF_OK) return error(context, oodf_last_error());
    RexxDirectoryObject event = context->NewDirectory();
    put(context, event, "RESOURCEID", std::to_string(buffer.resourceId));
    put(context, event, "UID", std::to_string(buffer.uid));
    put(context, event, "REVISION", std::to_string(buffer.revision));
    put(context, event, "NAME", name.data());
    put(context, event, "VALUE", value.data());
    put(context, event, "HANDLER", handler.data());
    return event;
}

RexxRoutine1(RexxObjectPtr, OodfNativeClose, CSTRING, token) {
    std::lock_guard<std::mutex> lock(sessionsMutex);
    uint64_t id{};
    if (!decimal(token, id)) return error(context, "invalid session token");
    Session *session = get(context, token);
    if (!session) return NULLOBJECT;
    HRESULT result = onDialogWindowThread(session->parent, [&] {
        return oodf_win_close(session->host);
    });
    if (FAILED(result)) return error(context, "WinUI host close failed: " + hex(result));
    oodf_close(session->model);
    sessions.erase(id);
    return context->True();
}

RexxRoutineEntry oodfluent_routines[] = {
    REXX_TYPED_ROUTINE(OodfNativeOpen, OodfNativeOpen),
    REXX_TYPED_ROUTINE(OodfNativeCreate, OodfNativeCreate),
    REXX_TYPED_ROUTINE(OodfNativeCreateAuthored, OodfNativeCreateAuthored),
    REXX_TYPED_ROUTINE(OodfNativeSet, OodfNativeSet),
    REXX_TYPED_ROUTINE(OodfNativeBind, OodfNativeBind),
    REXX_TYPED_ROUTINE(OodfNativeMove, OodfNativeMove),
    REXX_TYPED_ROUTINE(OodfNativeRemove, OodfNativeRemove),
    REXX_TYPED_ROUTINE(OodfNativePoll, OodfNativePoll),
    REXX_TYPED_ROUTINE(OodfNativeClose, OodfNativeClose),
    REXX_LAST_ROUTINE()
};

RexxPackageEntry OodFluentRexx_package_entry = {
    STANDARD_PACKAGE_HEADER
    REXX_INTERPRETER_5_0_0,
    "OodFluentRexx",
    "0.2.0",
    nullptr,
    nullptr,
    oodfluent_routines,
    nullptr
};

OOREXX_GET_PACKAGE(OodFluentRexx);
