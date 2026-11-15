// Architecture: Tom Dyer. Code: ChatGPT (GPT-6).
// Interactive-desktop host exercise: deliberately separate from BUILD qualification.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <DbgHelp.h>
#include <stdio.h>
#include <string>
#include "OodFluentIsland.h"
#pragma comment(lib, "Dbghelp.lib")

namespace {

void stage(const char *name) {
    fprintf(stderr, "STAGE %s\n", name);
    fflush(stderr);
}

int fail(const char *operation, HRESULT result) {
    fprintf(stderr, "FAIL %s HRESULT=0x%08lX\n", operation, (unsigned long)result);
    return 1;
}

LRESULT CALLBACK windowProcedure(HWND hwnd, UINT message, WPARAM w, LPARAM l) {
    if (message == WM_DESTROY) { PostQuitMessage(0); return 0; }
    return DefWindowProcW(hwnd, message, w, l);
}

LONG WINAPI recordNativeCrash(EXCEPTION_POINTERS *exception) {
    fprintf(stderr, "UNHANDLED_EXCEPTION code=0x%08lX address=%p\n",
            static_cast<unsigned long>(exception->ExceptionRecord->ExceptionCode),
            exception->ExceptionRecord->ExceptionAddress);
    HMODULE module{};
    if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                           GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                           reinterpret_cast<LPCWSTR>(exception->ExceptionRecord->ExceptionAddress), &module)) {
        fprintf(stderr, "FAULT_MODULE base=%p offset=0x%llX\n", module,
                 static_cast<unsigned long long>(
                     reinterpret_cast<uintptr_t>(exception->ExceptionRecord->ExceptionAddress) -
                     reinterpret_cast<uintptr_t>(module)));
    }
    wchar_t path[MAX_PATH]{};
    if (GetEnvironmentVariableW(L"OODF_CRASH_DUMP", path, MAX_PATH)) {
        HANDLE file = CreateFileW(path, GENERIC_WRITE, FILE_SHARE_READ, nullptr,
                                  CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (file != INVALID_HANDLE_VALUE) {
            MINIDUMP_EXCEPTION_INFORMATION crash{GetCurrentThreadId(), exception, FALSE};
            const BOOL recorded = MiniDumpWriteDump(GetCurrentProcess(), GetCurrentProcessId(),
                file, MiniDumpWithThreadInfo, &crash, nullptr, nullptr);
            fprintf(stderr, "MINIDUMP recorded=%d win32=%lu\n", recorded, GetLastError());
            CloseHandle(file);
        }
    }
    fflush(stderr);
    return EXCEPTION_EXECUTE_HANDLER;
}

} // namespace

int wmain(int argc, wchar_t **argv) {
    SetUnhandledExceptionFilter(recordNativeCrash);
    // Emitted before any call: if absent, loading the WinUI DLL itself blocked.
    stage("MAIN_ENTER");
    if (argc != 2) {
        fprintf(stderr, "usage: OodFluentSmoke <absolute-controls.tsv>\n");
        return 2;
    }
    // Each mode runs in its own process. An access violation in one WinUI
    // control's teardown must not prevent probing the other control families.
    wchar_t mode[32]{};
    if (!GetEnvironmentVariableW(L"OODF_SMOKE_MODE", mode, 32)) wcscpy_s(mode, L"all");
    const bool all = wcscmp(mode, L"all") == 0;
    const bool empty = wcscmp(mode, L"empty") == 0;
    const bool buttonOnly = wcscmp(mode, L"button") == 0;
    const bool toggleOnly = wcscmp(mode, L"toggle") == 0;
    const bool checkOnly = wcscmp(mode, L"check") == 0;
    const bool toggleButtonOnly = wcscmp(mode, L"togglebutton") == 0;
    const bool sliderOnly = wcscmp(mode, L"slider") == 0;
    const bool textBoxOnly = wcscmp(mode, L"textbox") == 0;
    const bool progressOnly = wcscmp(mode, L"progress") == 0;
    const bool expanded = wcscmp(mode, L"expanded") == 0;
    const bool qualified = wcscmp(mode, L"qualified") == 0;
    const bool infoOnly = wcscmp(mode, L"info") == 0;
    const bool numberOnly = wcscmp(mode, L"number") == 0;
    const bool noNumber = wcscmp(mode, L"no-number") == 0;
    const bool guard = wcscmp(mode, L"guard") == 0;
    if (!(all || empty || buttonOnly || toggleOnly || checkOnly || toggleButtonOnly ||
          sliderOnly || textBoxOnly || progressOnly || expanded || qualified ||
          infoOnly || numberOnly || noNumber || guard)) return 2;
    fprintf(stderr, "STAGE MODE_%s\n", all ? "all" : empty ? "empty" :
            buttonOnly ? "button" : toggleOnly ? "toggle" : checkOnly ? "check" :
            toggleButtonOnly ? "togglebutton" : sliderOnly ? "slider" :
            textBoxOnly ? "textbox" : progressOnly ? "progress" :
            expanded ? "expanded" : qualified ? "qualified" : infoOnly ? "info" :
            numberOnly ? "number" : noNumber ? "no-number" : "guard");
    fflush(stderr);
    const bool wantButton = all || buttonOnly || noNumber || expanded || qualified;
    const bool wantToggle = all || toggleOnly || noNumber || expanded || qualified;
    const bool wantCheck = all || checkOnly || expanded || qualified;
    const bool wantToggleButton = all || toggleButtonOnly || expanded || qualified;
    const bool wantSlider = all || sliderOnly || expanded || qualified;
    const bool wantTextBox = all || textBoxOnly || expanded;
    const bool wantProgress = all || progressOnly || expanded;
    const bool wantInfo = all || infoOnly || noNumber;
    const bool wantNumber = all || numberOnly;
    const std::wstring path = argv[1];
    const int needed = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
                                           path.c_str(), -1, nullptr, 0, nullptr, nullptr);
    if (!needed) return 2;
    std::string catalogue(needed, '\0');
    if (!WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, path.c_str(), -1,
                             catalogue.data(), needed, nullptr, nullptr)) return 2;

    OodfSession *model = nullptr;
    stage("MODEL_OPEN");
    auto status = oodf_open(catalogue.c_str(), 0, &model);
    if (status != OODF_OK) {
        fprintf(stderr, "FAIL catalogue: %s\n", oodf_last_error());
        return 2;
    }
    const wchar_t *windowClass = L"OodFluentWindowsSmokeHost";
    WNDCLASSW cls{};
    cls.hInstance = GetModuleHandleW(nullptr);
    cls.lpfnWndProc = windowProcedure;
    cls.lpszClassName = windowClass;
    RegisterClassW(&cls);
    HWND hwnd = CreateWindowExW(0, windowClass, L"ooDialog Fluent Runtime Smoke",
                                WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
                                640, 480, nullptr, nullptr, cls.hInstance, nullptr);
    if (!hwnd) { fprintf(stderr, "FAIL CreateWindow\n"); oodf_close(model); return 2; }
    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);
    stage("HWND_READY");

    OodfWinHost *host = nullptr;
    stage("ISLAND_OPEN_BEGIN");
    HRESULT result = oodf_win_open(hwnd, model, &host);
    if (FAILED(result)) {
        int code = fail("oodf_win_open", result);
        DestroyWindow(hwnd);
        oodf_close(model);
        return code;
    }
    stage("ISLAND_OPEN_OK");
    uint64_t button = 0, toggle = 0, check = 0, toggleButton = 0;
    uint64_t slider = 0, textBox = 0, progress = 0, info = 0, number = 0;
    wchar_t preUnload[32]{};
    (void)GetEnvironmentVariableW(L"OODF_PREUNLOAD", preUnload, 32);
    const bool unload = wcscmp(preUnload, L"unload") == 0 ||
                        wcscmp(preUnload, L"unload-pump") == 0;
    stage("CREATE_CONTROLS_BEGIN");
    if (FAILED(result = oodf_win_move(host, 4, 4, 600, 400))) goto cleanup;
    if (guard) {
        uint64_t denied = 0;
        const HRESULT infoDenied = oodf_win_add(host, 4103, L"InfoBar", L"Blocked", &denied);
        const HRESULT numberDenied = oodf_win_add(host, 4104, L"NumberBox", L"Blocked", &denied);
        const HRESULT textDenied = oodf_win_add(host, 4113, L"TextBox", L"Blocked", &denied);
        const HRESULT progressDenied = oodf_win_add(host, 4114, L"ProgressBar", L"Blocked", &denied);
        if (infoDenied != E_NOTIMPL || numberDenied != E_NOTIMPL ||
            textDenied != E_NOTIMPL || progressDenied != E_NOTIMPL || denied != 0) {
            result = E_UNEXPECTED;
            goto cleanup;
        }
        stage("UNQUALIFIED_CONTROLS_BLOCKED");
    }
    if (wantButton) {
        if (FAILED(result = oodf_win_add_authored(host, 4101, L"Button", L"Hello ooRexx", 71001, &button))) goto cleanup;
        if (button != 71001) { result = E_UNEXPECTED; goto cleanup; }
    }
    if (wantToggle && FAILED(result = oodf_win_add(host, 4102, L"ToggleSwitch", L"Dark mode", &toggle))) goto cleanup;
    if (wantCheck && FAILED(result = oodf_win_add(host, 4110, L"CheckBox", L"Accept", &check))) goto cleanup;
    if (wantToggleButton && FAILED(result = oodf_win_add(host, 4111, L"ToggleButton", L"Pin", &toggleButton))) goto cleanup;
    if (wantSlider && FAILED(result = oodf_win_add(host, 4112, L"Slider", L"Zoom", &slider))) goto cleanup;
    if (wantTextBox && FAILED(result = oodf_win_add(host, 4113, L"TextBox", L"Search", &textBox))) goto cleanup;
    if (wantProgress && FAILED(result = oodf_win_add(host, 4114, L"ProgressBar", L"Progress", &progress))) goto cleanup;
    if (wantInfo && FAILED(result = oodf_win_add(host, 4103, L"InfoBar", L"WinUI 3 is alive", &info))) goto cleanup;
    if (wantNumber && FAILED(result = oodf_win_add(host, 4104, L"NumberBox", L"Quantity", &number))) goto cleanup;
    stage("CREATE_CONTROLS_OK");
    if (wantButton && oodf_bind(model, button, "click", "onButton") != OODF_OK) {
        fprintf(stderr, "FAIL event binding: %s\n", oodf_last_error());
        result = E_FAIL;
        goto cleanup;
    }
    if (wantButton && FAILED(result = oodf_win_set(host, button, L"text", L"Updated from native API"))) goto cleanup;
    if (wantToggle && FAILED(result = oodf_win_set(host, toggle, L"isOn", L"true"))) goto cleanup;
    if (wantToggle && oodf_win_set(host, toggle, L"isOn", L"not-a-boolean") != E_INVALIDARG) {
        result = E_UNEXPECTED;
        goto cleanup;
    }
    if (wantCheck && FAILED(result = oodf_win_set(host, check, L"isChecked", L"true"))) goto cleanup;
    if (wantCheck && FAILED(result = oodf_win_set(host, check, L"isThreeState", L"true"))) goto cleanup;
    if (wantCheck && oodf_win_set(host, check, L"isChecked", L"unknown") != E_INVALIDARG) {
        result = E_UNEXPECTED;
        goto cleanup;
    }
    if (wantCheck && oodf_win_set(host, check, L"isChecked", L"null") != E_NOTIMPL) {
        result = E_UNEXPECTED;
        goto cleanup;
    }
    if (wantToggleButton && FAILED(result = oodf_win_set(host, toggleButton, L"isChecked", L"true"))) goto cleanup;
    if (wantSlider && FAILED(result = oodf_win_set(host, slider, L"value", L"42.5"))) goto cleanup;
    if (wantSlider && (oodf_win_set(host, slider, L"value", L"not-a-number") != E_INVALIDARG ||
                       oodf_win_set(host, slider, L"value", L"NaN") != E_INVALIDARG)) {
        result = E_UNEXPECTED;
        goto cleanup;
    }
    if (wantSlider && oodf_win_set(host, slider, L"unknownProperty", L"42") != E_NOTIMPL) {
        result = E_UNEXPECTED;
        goto cleanup;
    }
    if (wantTextBox && FAILED(result = oodf_win_set(host, textBox, L"text", L"Unicode Stra\u00DFe"))) goto cleanup;
    if (wantProgress && FAILED(result = oodf_win_set(host, progress, L"value", L"65"))) goto cleanup;
    if (wantNumber && FAILED(result = oodf_win_set(host, number, L"value", L"42"))) goto cleanup;
    if (wantInfo && FAILED(result = oodf_win_set(host, info, L"message", L"Property updates work"))) goto cleanup;
    // Pump a bounded burst of input/layout messages, not an infinite GUI loop.
    for (int i = 0; i < 40; ++i) {
        MSG message{};
        while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
            TranslateMessage(&message);
            DispatchMessageW(&message);
        }
        Sleep(20);
    }
    stage("PUMP_OK");
    if (unload) {
        stage("PREUNLOAD_BEGIN");
        if (wantInfo && FAILED(result = oodf_win_remove(host, info))) goto cleanup;
        if (wantNumber && FAILED(result = oodf_win_remove(host, number))) goto cleanup;
        if (wantToggle && FAILED(result = oodf_win_remove(host, toggle))) goto cleanup;
        stage("PREUNLOAD_DONE");
        if (wcscmp(preUnload, L"unload-pump") == 0) {
            // Deliberately outside the provider's destructor: pumping the
            // ooDialog UI thread while its close mutex is held is unsafe.
            for (int i = 0; i < 40; ++i) {
                MSG message{};
                while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
                    TranslateMessage(&message);
                    DispatchMessageW(&message);
                }
                Sleep(20);
            }
            stage("PREUNLOAD_PUMP_OK");
        }
    }
    if (wantButton && FAILED(result = oodf_win_remove(host, button))) goto cleanup;
    if (wantCheck && FAILED(result = oodf_win_remove(host, check))) goto cleanup;
    if (wantCheck && oodf_win_set(host, check, L"isChecked", L"false") !=
                     HRESULT_FROM_WIN32(ERROR_NOT_FOUND)) {
        result = E_UNEXPECTED;
        goto cleanup;
    }
    if (wantToggleButton && FAILED(result = oodf_win_remove(host, toggleButton))) goto cleanup;
    if (wantSlider && FAILED(result = oodf_win_remove(host, slider))) goto cleanup;
    if (wantTextBox && FAILED(result = oodf_win_remove(host, textBox))) goto cleanup;
    if (wantProgress && FAILED(result = oodf_win_remove(host, progress))) goto cleanup;
    stage("OPERATIONS_OK");
cleanup:
    stage("TEARDOWN_BEGIN");
    if (FAILED(result)) fail("native host operation", result);
    const HRESULT closed = oodf_win_close(host);
    if (FAILED(closed)) fail("oodf_win_close", closed);
    DestroyWindow(hwnd);
    oodf_close(model);
    stage("TEARDOWN_DONE");
    if (!FAILED(result) && !FAILED(closed)) printf("PASS native HWND/XAML island mode=%ls properties, remove, close\n", mode);
    return FAILED(result) || FAILED(closed) ? 1 : 0;
}
