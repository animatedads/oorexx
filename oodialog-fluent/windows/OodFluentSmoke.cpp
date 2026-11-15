// Architecture: Tom Dyer. Code: ChatGPT (GPT-6).
// Interactive-desktop host exercise: deliberately separate from BUILD qualification.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <string>
#include "OodFluentIsland.h"

namespace {

int fail(const char *operation, HRESULT result) {
    fprintf(stderr, "FAIL %s HRESULT=0x%08lX\n", operation, (unsigned long)result);
    return 1;
}

LRESULT CALLBACK windowProcedure(HWND hwnd, UINT message, WPARAM w, LPARAM l) {
    if (message == WM_DESTROY) { PostQuitMessage(0); return 0; }
    return DefWindowProcW(hwnd, message, w, l);
}

} // namespace

int wmain(int argc, wchar_t **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: OodFluentSmoke <absolute-controls.tsv>\n");
        return 2;
    }
    const std::wstring path = argv[1];
    const int needed = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
                                           path.c_str(), -1, nullptr, 0, nullptr, nullptr);
    if (!needed) return 2;
    std::string catalogue(needed, '\0');
    if (!WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, path.c_str(), -1,
                             catalogue.data(), needed, nullptr, nullptr)) return 2;

    OodfSession *model = nullptr;
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

    OodfWinHost *host = nullptr;
    HRESULT result = oodf_win_open(hwnd, model, &host);
    if (FAILED(result)) {
        int code = fail("oodf_win_open", result);
        DestroyWindow(hwnd);
        oodf_close(model);
        return code;
    }
    uint64_t button = 0, toggle = 0, info = 0, number = 0;
    if (FAILED(result = oodf_win_move(host, 4, 4, 600, 400))) goto cleanup;
    if (FAILED(result = oodf_win_add_authored(host, 4101, L"Button", L"Hello ooRexx", 71001, &button))) goto cleanup;
    if (button != 71001) { result = E_UNEXPECTED; goto cleanup; }
    if (FAILED(result = oodf_win_add(host, 4102, L"ToggleSwitch", L"Dark mode", &toggle))) goto cleanup;
    if (FAILED(result = oodf_win_add(host, 4103, L"InfoBar", L"WinUI 3 is alive", &info))) goto cleanup;
    if (FAILED(result = oodf_win_add(host, 4104, L"NumberBox", L"Quantity", &number))) goto cleanup;
    if (oodf_bind(model, button, "click", "onButton") != OODF_OK) {
        fprintf(stderr, "FAIL event binding: %s\n", oodf_last_error());
        result = E_FAIL;
        goto cleanup;
    }
    if (FAILED(result = oodf_win_set(host, button, L"text", L"Updated from native API"))) goto cleanup;
    if (FAILED(result = oodf_win_set(host, toggle, L"isOn", L"true"))) goto cleanup;
    if (FAILED(result = oodf_win_set(host, number, L"value", L"42"))) goto cleanup;
    if (FAILED(result = oodf_win_set(host, info, L"message", L"Property updates work"))) goto cleanup;
    // Pump a bounded burst of input/layout messages, not an infinite GUI loop.
    for (int i = 0; i < 40; ++i) {
        MSG message{};
        while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
            TranslateMessage(&message);
            DispatchMessageW(&message);
        }
        Sleep(20);
    }
    if (FAILED(result = oodf_win_remove(host, button))) goto cleanup;
    printf("PASS native Windows HWND/XAML island, 4 controls, properties, remove, close\n");
cleanup:
    if (FAILED(result)) fail("native host operation", result);
    const HRESULT closed = oodf_win_close(host);
    if (FAILED(closed)) fail("oodf_win_close", closed);
    DestroyWindow(hwnd);
    oodf_close(model);
    return FAILED(result) || FAILED(closed) ? 1 : 0;
}
