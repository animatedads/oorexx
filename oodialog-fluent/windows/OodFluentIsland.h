// Architecture: Tom Dyer. Code: ChatGPT (GPT-6).
// Windows-only WinUI 3 island C ABI. All functions must run on the dialog UI thread.
#pragma once
#include <windows.h>
#include <stdint.h>
#include "OodFluentABI.h"

#ifdef OODF_BUILD_DLL
#  define OODF_WIN_API __declspec(dllexport)
#else
#  define OODF_WIN_API __declspec(dllimport)
#endif

typedef struct OodfWinHost OodfWinHost;

#ifdef __cplusplus
extern "C" {
#endif

// A caller must open the model first and close the island before the model.
OODF_WIN_API HRESULT __stdcall oodf_win_open(HWND parent, OodfSession *model, OodfWinHost **out);
OODF_WIN_API HRESULT __stdcall oodf_win_add(OodfWinHost *host, int64_t resourceId,
    const wchar_t *kind, const wchar_t *caption, uint64_t *uid);
OODF_WIN_API HRESULT __stdcall oodf_win_set(OodfWinHost *host, uint64_t uid,
    const wchar_t *property, const wchar_t *value);
OODF_WIN_API HRESULT __stdcall oodf_win_move(OodfWinHost *host, int x, int y, int width, int height);
OODF_WIN_API HRESULT __stdcall oodf_win_remove(OodfWinHost *host, uint64_t uid);
OODF_WIN_API HRESULT __stdcall oodf_win_close(OodfWinHost *host);

#ifdef __cplusplus
}
#endif
