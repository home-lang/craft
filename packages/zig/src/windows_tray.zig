const std = @import("std");
const builtin = @import("builtin");

// Only compile on Windows
pub const WindowsTray = if (builtin.os.tag == .windows) WindowsTrayImpl else struct {
    pub fn init(_: std.mem.Allocator, _: *anyopaque, _: []const u8) !WindowsTray {
        return error.UnsupportedPlatform;
    }
    pub fn deinit(_: *WindowsTray) void {}
    pub fn setTooltip(_: *WindowsTray, _: []const u8) !void {}
    pub fn setTitle(_: *WindowsTray, _: []const u8) !void {}
};

const WindowsTrayImpl = if (builtin.os.tag == .windows) struct {
    const windows = std.os.windows;

    // Windows API constants
    const WM_USER = 0x0400;
    pub const WM_TRAYICON = WM_USER + 1;
    const NIM_ADD = 0x00000000;
    const NIM_MODIFY = 0x00000001;
    const NIM_DELETE = 0x00000002;
    const NIF_MESSAGE = 0x00000001;
    const NIF_ICON = 0x00000002;
    const NIF_TIP = 0x00000004;
    const NIF_INFO = 0x00000010;
    const HWND_MESSAGE: windows.HWND = @ptrFromInt(@as(usize, @bitCast(@as(isize, -3))));
    const WS_OVERLAPPED: windows.DWORD = 0x00000000;

    const NOTIFYICONDATA = extern struct {
        cbSize: windows.DWORD,
        hWnd: windows.HWND,
        uID: windows.UINT,
        uFlags: windows.UINT,
        uCallbackMessage: windows.UINT,
        hIcon: windows.HICON,
        szTip: [128]u16,
        dwState: windows.DWORD,
        dwStateMask: windows.DWORD,
        szInfo: [256]u16,
        uVersion: windows.UINT,
        szInfoTitle: [64]u16,
        dwInfoFlags: windows.DWORD,
        guidItem: windows.GUID,
        hBalloonIcon: windows.HICON,
    };

    extern "shell32" fn Shell_NotifyIconW(
        dwMessage: windows.DWORD,
        lpData: *NOTIFYICONDATA,
    ) callconv(windows.WINAPI) windows.BOOL;

    extern "user32" fn LoadIconW(
        hInstance: ?windows.HINSTANCE,
        lpIconName: windows.LPCWSTR,
    ) callconv(windows.WINAPI) ?windows.HICON;

    extern "user32" fn DestroyIcon(
        hIcon: windows.HICON,
    ) callconv(windows.WINAPI) windows.BOOL;

    extern "user32" fn CreateWindowExW(
        dwExStyle: windows.DWORD,
        lpClassName: windows.LPCWSTR,
        lpWindowName: windows.LPCWSTR,
        dwStyle: windows.DWORD,
        X: c_int,
        Y: c_int,
        nWidth: c_int,
        nHeight: c_int,
        hWndParent: ?windows.HWND,
        hMenu: ?windows.HMENU,
        hInstance: ?windows.HINSTANCE,
        lpParam: ?windows.LPVOID,
    ) callconv(windows.WINAPI) ?windows.HWND;

    extern "kernel32" fn GetModuleHandleW(
        lpModuleName: ?windows.LPCWSTR,
    ) callconv(windows.WINAPI) ?windows.HINSTANCE;

    hwnd: windows.HWND,
    icon_id: windows.UINT,
    notify_data: NOTIFYICONDATA,
    allocator: std.mem.Allocator,
    owns_window: bool,

    pub fn init(
        allocator: std.mem.Allocator,
        hwnd_ptr: ?*anyopaque,
        title: []const u8,
    ) !WindowsTrayImpl {
        // Create a message-only window if no hwnd provided
        const hwnd = if (hwnd_ptr) |ptr|
            @as(windows.HWND, @ptrCast(ptr))
        else blk: {
            // Get module handle
            const hInstance = GetModuleHandleW(null);

            // Class name for message window
            var class_name_buf = [_]u16{ 'Z', 'y', 't', 'e', 'T', 'r', 'a', 'y', 0 };
            const class_name: windows.LPCWSTR = &class_name_buf;

            // Create message-only window
            const hwnd_result = CreateWindowExW(
                0,
                class_name,
                class_name,
                WS_OVERLAPPED,
                0,
                0,
                0,
                0,
                HWND_MESSAGE, // Message-only window
                null,
                hInstance,
                null,
            );

            break :blk hwnd_result orelse return error.FailedToCreateWindow;
        };

        var tray = WindowsTrayImpl{
            .hwnd = hwnd,
            .icon_id = 1,
            .notify_data = std.mem.zeroes(NOTIFYICONDATA),
            .allocator = allocator,
            .owns_window = (hwnd_ptr == null),
        };

        tray.notify_data.cbSize = @sizeOf(NOTIFYICONDATA);
        tray.notify_data.hWnd = hwnd;
        tray.notify_data.uID = 1;
        tray.notify_data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
        tray.notify_data.uCallbackMessage = WM_TRAYICON;

        // Load default application icon (IDI_APPLICATION = 32512)
        const IDI_APPLICATION: windows.LPCWSTR = @ptrFromInt(32512);
        tray.notify_data.hIcon = LoadIconW(null, IDI_APPLICATION) orelse {
            return error.FailedToLoadIcon;
        };

        // Set initial tooltip
        try tray.setTooltip(title);

        // Add to system tray
        if (Shell_NotifyIconW(NIM_ADD, &tray.notify_data) == 0) {
            return error.FailedToCreateTray;
        }

        return tray;
    }

    extern "user32" fn DestroyWindow(
        hWnd: windows.HWND,
    ) callconv(windows.WINAPI) windows.BOOL;

    pub fn deinit(self: *WindowsTrayImpl) void {
        _ = Shell_NotifyIconW(NIM_DELETE, &self.notify_data);
        if (self.notify_data.hIcon) |icon| {
            _ = DestroyIcon(icon);
        }
        // Destroy the window if we created it
        if (self.owns_window) {
            _ = DestroyWindow(self.hwnd);
        }
    }

    pub fn setTooltip(self: *WindowsTrayImpl, tooltip: []const u8) !void {
        // Convert UTF-8 to UTF-16
        var utf16_buffer: [128]u16 = undefined;
        const utf16_len = try std.unicode.utf8ToUtf16Le(&utf16_buffer, tooltip);

        // Copy to notify_data and null-terminate
        const copy_len = @min(utf16_len, self.notify_data.szTip.len - 1);
        @memcpy(self.notify_data.szTip[0..copy_len], utf16_buffer[0..copy_len]);
        self.notify_data.szTip[copy_len] = 0;

        // Update if already created
        if (self.notify_data.hWnd != null) {
            _ = Shell_NotifyIconW(NIM_MODIFY, &self.notify_data);
        }
    }

    pub fn setTitle(self: *WindowsTrayImpl, title: []const u8) !void {
        // On Windows, title is the tooltip
        try self.setTooltip(title);
    }

    pub fn showBalloon(
        self: *WindowsTrayImpl,
        title: []const u8,
        message: []const u8,
    ) !void {
        // Set balloon title
        var title_utf16: [64]u16 = undefined;
        const title_len = try std.unicode.utf8ToUtf16Le(&title_utf16, title);
        const title_copy_len = @min(title_len, self.notify_data.szInfoTitle.len - 1);
        @memcpy(self.notify_data.szInfoTitle[0..title_copy_len], title_utf16[0..title_copy_len]);
        self.notify_data.szInfoTitle[title_copy_len] = 0;

        // Set balloon message
        var msg_utf16: [256]u16 = undefined;
        const msg_len = try std.unicode.utf8ToUtf16Le(&msg_utf16, message);
        const msg_copy_len = @min(msg_len, self.notify_data.szInfo.len - 1);
        @memcpy(self.notify_data.szInfo[0..msg_copy_len], msg_utf16[0..msg_copy_len]);
        self.notify_data.szInfo[msg_copy_len] = 0;

        self.notify_data.uFlags |= NIF_INFO;
        self.notify_data.dwInfoFlags = 1; // NIIF_INFO

        _ = Shell_NotifyIconW(NIM_MODIFY, &self.notify_data);
    }
} else struct {};

pub const TrayEvent = enum {
    left_click,
    left_double_click,
    right_click,
    unknown,
};

pub fn handleTrayMessage(wparam: usize, lparam: usize) TrayEvent {
    if (builtin.os.tag != .windows) return .unknown;

    const WM_LBUTTONDOWN = 0x0201;
    const WM_RBUTTONDOWN = 0x0204;
    const WM_LBUTTONDBLCLK = 0x0203;

    _ = wparam; // icon_id
    const message = @as(u32, @intCast(lparam & 0xFFFF));

    return switch (message) {
        WM_LBUTTONDOWN => .left_click,
        WM_LBUTTONDBLCLK => .left_double_click,
        WM_RBUTTONDOWN => .right_click,
        else => .unknown,
    };
}
