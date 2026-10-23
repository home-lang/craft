/* Independent ABI input. Use the actual pinned Khronos SDK headers. */
#define VK_NO_PROTOTYPES 1
#if defined(_WIN32)
#include <windows.h>
#endif
#if defined(__linux__) && !defined(__ANDROID__)
#include <X11/Xlib.h>
#endif
#include <vulkan/vulkan_core.h>
#include <vulkan/vulkan_android.h>
#if defined(_WIN32)
#include <vulkan/vulkan_win32.h>
#endif
#if defined(__linux__) && !defined(__ANDROID__)
#include <vulkan/vulkan_xlib.h>
#endif
