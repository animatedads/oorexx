// Architecture: Tom Dyer. Code: ChatGPT (GPT-6).
// Windows App SDK 2.6 WinUI 3 proof candidate; BUILD qualification != RUN qualification.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <objidl.h>
#include <combaseapi.h>
#include <MddBootstrap.h>
#include <WindowsAppSDK-VersionInfo.h>
#ifdef GetCurrentTime
#undef GetCurrentTime
#endif
#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Microsoft.UI.Dispatching.h>
#include <winrt/Microsoft.UI.Content.h>
#include <winrt/Microsoft.UI.Interop.h>
#include <winrt/Microsoft.UI.Xaml.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Controls.Primitives.h>
#include <winrt/Microsoft.UI.Xaml.Hosting.h>
#include <winrt/Windows.Graphics.h>
#include "OodFluentIsland.h"

#include <cstdio>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <utility>

namespace ui = winrt::Microsoft::UI;
namespace xaml = winrt::Microsoft::UI::Xaml;
namespace controls = winrt::Microsoft::UI::Xaml::Controls;
namespace hosting = winrt::Microsoft::UI::Xaml::Hosting;

static void lifecycleTrace(const char *stage) noexcept {
    char enabled[2]{};
    if (!GetEnvironmentVariableA("OODF_LIFECYCLE_TRACE", enabled, sizeof(enabled))) return;
    fprintf(stderr, "HOST_STAGE %s\n", stage);
    fflush(stderr);
}

struct OodfComApartment {
    bool owned = false;
    ~OodfComApartment() {
        lifecycleTrace("COM_UNINIT_BEGIN");
        if (owned) winrt::uninit_apartment();
        lifecycleTrace("COM_UNINIT_DONE");
    }
};

struct OodfBootstrapScope {
    // The runtime dependency is process-wide; concurrent dialogs share one
    // initialization and release it after the last island is destroyed.
    static std::mutex mutex;
    static size_t references;
    bool owned = false;

    void initialize() {
        std::lock_guard<std::mutex> lock(mutex);
        if (references == 0) {
            // COM has already been initialized for the current STA.
            PACKAGE_VERSION minVersion{};
            minVersion.Version = WINDOWSAPPSDK_RUNTIME_VERSION_UINT64;
            winrt::check_hresult(MddBootstrapInitialize(WINDOWSAPPSDK_RELEASE_MAJORMINOR,
                WINDOWSAPPSDK_RELEASE_VERSION_TAG_W, minVersion));
        }
        ++references;
        owned = true;
    }

    ~OodfBootstrapScope() {
        if (!owned) return;
        std::lock_guard<std::mutex> lock(mutex);
        lifecycleTrace("BOOTSTRAP_RELEASE_BEGIN");
        if (--references == 0) MddBootstrapShutdown();
        lifecycleTrace("BOOTSTRAP_RELEASE_DONE");
    }
};

std::mutex OodfBootstrapScope::mutex;
size_t OodfBootstrapScope::references = 0;

struct OodfWinHost {
    OodfComApartment apartmentScope;
    OodfBootstrapScope bootstrapScope;
    DWORD uiThread{};
    OodfSession *model{}; // borrowed: ooRexx/native package owns the model
    ui::Dispatching::DispatcherQueueController queue{nullptr};
    hosting::WindowsXamlManager manager{nullptr};
    hosting::DesktopWindowXamlSource island{nullptr};
    controls::StackPanel root{nullptr};
    std::map<uint64_t, xaml::FrameworkElement> children;

    explicit OodfWinHost(HWND parent, OodfSession *session)
        : uiThread(GetCurrentThreadId()), model(session) {
        APTTYPE apartment{};
        APTTYPEQUALIFIER qualifier{};
        const HRESULT apartmentStatus = CoGetApartmentType(&apartment, &qualifier);
        if (apartmentStatus == CO_E_NOTINITIALIZED) {
            winrt::init_apartment(winrt::apartment_type::single_threaded);
            apartmentScope.owned = true;
        } else {
            winrt::check_hresult(apartmentStatus);
            if (apartment != APTTYPE_STA && apartment != APTTYPE_MAINSTA)
                winrt::throw_hresult(RPC_E_WRONG_THREAD);
        }
        bootstrapScope.initialize();
        if (!ui::Dispatching::DispatcherQueue::GetForCurrentThread())
            queue = ui::Dispatching::DispatcherQueueController::CreateOnCurrentThread();
        manager = hosting::WindowsXamlManager::InitializeForCurrentThread();
        island = hosting::DesktopWindowXamlSource{};
        island.Initialize(ui::GetWindowIdFromWindow(parent));
        root = controls::StackPanel{};
        root.Spacing(8.0);
        island.Content(root);
    }

    ~OodfWinHost() {
        // Native event delegates live on the XAML controls and are detached with them.
        // No Rexx callback is invoked during destruction.
        lifecycleTrace("CLEAR_CHILDREN_BEGIN");
        children.clear();
        if (root) root.Children().Clear();
        lifecycleTrace("CLEAR_CHILDREN_DONE");
        if (island) island.Content(xaml::UIElement{nullptr});
        root = nullptr;
        lifecycleTrace("CLOSE_ISLAND_BEGIN");
        if (island) island.Close();
        island = nullptr;
        lifecycleTrace("CLOSE_ISLAND_DONE");
        if (manager) manager.Close();
        manager = nullptr;
        lifecycleTrace("CLOSE_MANAGER_DONE");
        // If we created a DispatcherQueue, it is owned by this UI thread and may
        // still be needed by other islands; its shutdown belongs to thread teardown.
    }
};

namespace {

HRESULT status(OodfStatus result) noexcept {
    return result == OODF_OK ? S_OK : HRESULT_FROM_WIN32(ERROR_INVALID_DATA);
}

bool wrongThread(OodfWinHost *host) noexcept {
    return host->uiThread != GetCurrentThreadId();
}

void event(OodfSession *model, uint64_t uid, const char *name, const std::string &value) {
    int queued = 0;
    // Callback enqueues only; Rexx handlers execute later in the ooDialog pump.
    (void)oodf_raise(model, uid, name, value.c_str(), &queued);
}

template<typename Operation>
HRESULT safe(Operation &&operation) noexcept {
    try {
        operation();
        return S_OK;
    } catch (winrt::hresult_error const &error) {
        return error.code();
    } catch (...) {
        return E_FAIL;
    }
}

} // namespace

extern "C" {

HRESULT __stdcall oodf_win_open(HWND parent, OodfSession *model, OodfWinHost **out) {
    if (!parent || !IsWindow(parent) || !model || !out) return E_INVALIDARG;
    *out = nullptr;
    return safe([&] {
        auto host = std::make_unique<OodfWinHost>(parent, model);
        *out = host.release();
    });
}

static HRESULT oodf_win_add_impl(OodfWinHost *host, int64_t resourceId,
                                 const wchar_t *kind, const wchar_t *caption,
                                 bool authored, uint64_t authoredUid, uint64_t *uid) {
    if (!host || !kind || !caption || !uid) return E_INVALIDARG;
    if (wrongThread(host)) return RPC_E_WRONG_THREAD;
    return safe([&] {
        const auto type = winrt::to_string(winrt::hstring(kind));
        const auto label = winrt::hstring(caption);
        if (type != "Button" && type != "ToggleSwitch" &&
            type != "InfoBar" && type != "NumberBox") winrt::throw_hresult(E_NOTIMPL);
        uint64_t id = 0;
        auto created = authored ? oodf_create_authored(host->model, resourceId, type.c_str(), authoredUid, &id)
                               : oodf_create(host->model, resourceId, type.c_str(), &id);
        winrt::check_hresult(status(created));
        try {
            xaml::FrameworkElement element{nullptr};
            if (type == "Button") {
                controls::Button button{};
                button.Content(winrt::box_value(label));
                button.Click([model = host->model, id](auto const &, auto const &) {
                    event(model, id, "click", "");
                });
                element = button;
                winrt::check_hresult(status(oodf_set(host->model, id, "text", winrt::to_string(label).c_str())));
            } else if (type == "ToggleSwitch") {
                controls::ToggleSwitch toggle{};
                toggle.Header(winrt::box_value(label));
                toggle.Toggled([model = host->model, id](auto const &sender, auto const &) {
                    auto toggle = sender.template as<controls::ToggleSwitch>();
                    event(model, id, "toggled", toggle.IsOn() ? "true" : "false");
                });
                element = toggle;
                winrt::check_hresult(status(oodf_set(host->model, id, "text", winrt::to_string(label).c_str())));
            } else if (type == "InfoBar") {
                controls::InfoBar bar{};
                bar.Message(label);
                bar.IsOpen(true);
                bar.Closed([model = host->model, id](auto const &, auto const &) {
                    event(model, id, "closed", "");
                });
                element = bar;
                winrt::check_hresult(status(oodf_set(host->model, id, "message", winrt::to_string(label).c_str())));
            } else {
                controls::NumberBox number{};
                number.Header(winrt::box_value(label));
                number.ValueChanged([model = host->model, id](auto const &, auto const &args) {
                    event(model, id, "valueChanged", std::to_string(args.NewValue()));
                });
                element = number;
            }
            host->root.Children().Append(element);
            host->children.emplace(id, element);
            *uid = id;
        } catch (...) {
            (void)oodf_remove(host->model, id);
            throw;
        }
    });
}

HRESULT __stdcall oodf_win_add(OodfWinHost *host, int64_t resourceId,
                               const wchar_t *kind, const wchar_t *caption, uint64_t *uid) {
    return oodf_win_add_impl(host, resourceId, kind, caption, false, 0, uid);
}

HRESULT __stdcall oodf_win_add_authored(OodfWinHost *host, int64_t resourceId,
                                        const wchar_t *kind, const wchar_t *caption,
                                        uint64_t authoredUid, uint64_t *uid) {
    if (!authoredUid) return E_INVALIDARG;
    return oodf_win_add_impl(host, resourceId, kind, caption, true, authoredUid, uid);
}

HRESULT __stdcall oodf_win_set(OodfWinHost *host, uint64_t uid,
                               const wchar_t *property, const wchar_t *value) {
    if (!host || !property || !value) return E_INVALIDARG;
    if (wrongThread(host)) return RPC_E_WRONG_THREAD;
    auto it = host->children.find(uid);
    if (it == host->children.end()) return HRESULT_FROM_WIN32(ERROR_NOT_FOUND);
    return safe([&] {
        auto name = winrt::to_string(winrt::hstring(property));
        auto utf8 = winrt::to_string(winrt::hstring(value));
        // Check the supported native mapping before changing either projection.
        const auto control = it->second;
        const bool isButton = control.try_as<controls::Button>() != nullptr;
        const bool isToggle = control.try_as<controls::ToggleSwitch>() != nullptr;
        const bool isInfo = control.try_as<controls::InfoBar>() != nullptr;
        const bool isNumber = control.try_as<controls::NumberBox>() != nullptr;
        if (!((isButton && name == "text") || (isToggle && (name == "text" || name == "isOn")) ||
              (isInfo && (name == "message" || name == "isOpen")) || (isNumber && name == "value")))
            winrt::throw_hresult(E_NOTIMPL);
        if (isButton) control.as<controls::Button>().Content(winrt::box_value(winrt::hstring(value)));
        if (isToggle && name == "text") control.as<controls::ToggleSwitch>().Header(winrt::box_value(winrt::hstring(value)));
        if (isToggle && name == "isOn") control.as<controls::ToggleSwitch>().IsOn(utf8 == "true");
        if (isInfo && name == "message") control.as<controls::InfoBar>().Message(value);
        if (isInfo && name == "isOpen") control.as<controls::InfoBar>().IsOpen(utf8 == "true");
        if (isNumber) control.as<controls::NumberBox>().Value(std::stod(utf8));
        winrt::check_hresult(status(oodf_set(host->model, uid, name.c_str(), utf8.c_str())));
    });
}

HRESULT __stdcall oodf_win_move(OodfWinHost *host, int x, int y, int width, int height) {
    if (!host || width < 0 || height < 0) return E_INVALIDARG;
    if (wrongThread(host)) return RPC_E_WRONG_THREAD;
    return safe([&] { host->island.SiteBridge().MoveAndResize(winrt::Windows::Graphics::RectInt32{x, y, width, height}); });
}

HRESULT __stdcall oodf_win_remove(OodfWinHost *host, uint64_t uid) {
    if (!host) return E_INVALIDARG;
    if (wrongThread(host)) return RPC_E_WRONG_THREAD;
    auto it = host->children.find(uid);
    if (it == host->children.end()) return HRESULT_FROM_WIN32(ERROR_NOT_FOUND);
    return safe([&] {
        uint32_t index = 0;
        if (!host->root.Children().IndexOf(it->second, index)) winrt::throw_hresult(E_UNEXPECTED);
        host->root.Children().RemoveAt(index);
        host->children.erase(it);
        winrt::check_hresult(status(oodf_remove(host->model, uid)));
    });
}

HRESULT __stdcall oodf_win_close(OodfWinHost *host) {
    if (!host) return E_INVALIDARG;
    if (wrongThread(host)) return RPC_E_WRONG_THREAD;
    return safe([&] {
        // Remove model entries and pending events before releasing the XAML objects.
        for (const auto &[uid, unused] : host->children) {
            (void)unused;
            (void)oodf_remove(host->model, uid);
        }
        delete host;
    });
}

} // extern C
